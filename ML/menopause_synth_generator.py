"""
Menopause Thermoregulation — Synthetic Training Data Generator
==============================================================
Target:  time_to_next_hf (seconds until next hot flash onset, capped at 7200s)
Model:   LSTM / Transformer on continuous time series
Signals: skin_temp (wrist °C), heart_rate (BPM) — no GSR
Source:  Gombert-Labedens et al. (2025) "Effects of menopause on temperature
         regulation" — Temperature (Austin) 12(2):92–132

Severity scale: 0 = none, 1 = very mild, 2 = mild, 3 = moderate, 4 = severe, 5 = very severe

Usage:
    from menopause_synth_generator import generate_cohort
    train_df, val_df, test_df, full_df, summary = generate_cohort(
        n_subjects=200, duration_hours=24, interval_sec=30, seed=42
    )
"""

import math
import numpy as np
import pandas as pd
from dataclasses import dataclass, field
from typing import Optional, Tuple, Dict, List

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS & LOOKUP TABLES
# ═══════════════════════════════════════════════════════════════════════════════

MAX_HORIZON_SEC = 7200  # regression target cap (2 hours)

RACE_OPTIONS = [
    "African American", "Hispanic/Latina", "White/Caucasian",
    "South Asian", "East Asian", "Other"
]
RACE_HF_PREVALENCE = {
    "African American": 0.80, "Hispanic/Latina": 0.70,
    "White/Caucasian": 0.65, "South Asian": 0.60,
    "East Asian": 0.40, "Other": 0.60,
}
RACE_ENCODE = {r: i for i, r in enumerate(RACE_OPTIONS)}

STAGE_OPTIONS = [
    "Early Perimenopause", "Late Perimenopause",
    "Early Postmenopause (0-2y)", "Late Postmenopause (2-5y)",
    "Late Postmenopause (5y+)"
]
STAGE_MULTIPLIER = {
    "Early Perimenopause": 0.4, "Late Perimenopause": 0.75,
    "Early Postmenopause (0-2y)": 1.0, "Late Postmenopause (2-5y)": 0.85,
    "Late Postmenopause (5y+)": 0.55,
}
STAGE_ENCODE = {s: i for i, s in enumerate(STAGE_OPTIONS)}

MED_OPTIONS = [
    "None", "SSRIs/SNRIs", "Tamoxifen", "Aromatase Inhibitors",
    "GnRH Agonists", "Beta Blockers", "Opioids", "Anticholinergics",
    "HRT (Estrogen)", "Fezolinetant (NK3R antagonist)"
]
MED_THERMOREG_EFFECT = {
    "None": 0, "SSRIs/SNRIs": -0.15, "Tamoxifen": 0.30,
    "Aromatase Inhibitors": 0.25, "GnRH Agonists": 0.35,
    "Beta Blockers": -0.10, "Opioids": 0.10, "Anticholinergics": 0.15,
    "HRT (Estrogen)": -0.40, "Fezolinetant (NK3R antagonist)": -0.50,
}
MED_ENCODE = {m: i for i, m in enumerate(MED_OPTIONS)}

SMOKE_ENCODE = {"Never": 0, "Former": 1, "Current": 2}
ALCOHOL_ENCODE = {"None": 0, "Light": 1, "Moderate": 2, "Heavy": 3}
STRESS_ENCODE = {"Low": 0, "Moderate": 1, "High": 2}
CAFFEINE_ENCODE = {"None": 0, "Light": 1, "Moderate": 2, "Heavy": 3}
EXERCISE_ENCODE = {"Sedentary": 0, "Light": 1, "Moderate": 2, "High": 3}

# Weighted pools for realistic random profile generation
_SMOKE_POOL = ["Never"] * 5 + ["Former"] * 3 + ["Current"] * 2
_ALC_POOL = ["None"] * 2 + ["Light"] * 4 + ["Moderate"] * 3 + ["Heavy"] * 1
_MED_POOL = (["None"] * 10 + ["SSRIs/SNRIs"] * 2 + ["Tamoxifen"] * 1 +
             ["HRT (Estrogen)"] * 2 + ["Fezolinetant (NK3R antagonist)"] * 1 +
             ["Beta Blockers"] * 1 + ["Aromatase Inhibitors"] * 1)
_STRESS_POOL = ["Low"] * 3 + ["Moderate"] * 5 + ["High"] * 2
_CAFF_POOL = ["None"] * 1 + ["Light"] * 2 + ["Moderate"] * 4 + ["Heavy"] * 3
_EXER_POOL = ["Sedentary"] * 2 + ["Light"] * 3 + ["Moderate"] * 4 + ["High"] * 1


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class PatientProfile:
    age: int = 52
    bmi: float = 26.5
    race: str = "White/Caucasian"
    stage: str = "Early Postmenopause (0-2y)"
    smoking: str = "Never"
    alcohol: str = "Light"
    medication: str = "None"
    stress: str = "Moderate"
    caffeine: str = "Moderate"
    exercise: str = "Moderate"
    thyroid: bool = False
    diabetes: bool = False
    cardiovascular: bool = False
    mental_health: bool = False
    surgical_menopause: bool = False


def random_profile(rng: np.random.Generator) -> PatientProfile:
    """Generate a randomized but realistic patient profile."""
    return PatientProfile(
        age=int(rng.integers(42, 63)),
        bmi=round(float(np.clip(rng.normal(27.5, 5.0), 17, 45)), 1),
        race=rng.choice(RACE_OPTIONS),
        stage=rng.choice(STAGE_OPTIONS),
        smoking=rng.choice(_SMOKE_POOL),
        alcohol=rng.choice(_ALC_POOL),
        medication=rng.choice(_MED_POOL),
        stress=rng.choice(_STRESS_POOL),
        caffeine=rng.choice(_CAFF_POOL),
        exercise=rng.choice(_EXER_POOL),
        thyroid=bool(rng.random() < 0.12),
        diabetes=bool(rng.random() < 0.10),
        cardiovascular=bool(rng.random() < 0.08),
        mental_health=bool(rng.random() < 0.20),
        surgical_menopause=bool(rng.random() < 0.08),
    )


# ═══════════════════════════════════════════════════════════════════════════════
# PHYSIOLOGICAL MODEL
# ═══════════════════════════════════════════════════════════════════════════════

def _compute_hourly_hf_probability(p: PatientProfile) -> float:
    """Compute per-hour hot flash probability based on profile risk factors."""
    prob = 0.08  # base rate

    # Menopause stage (peak = early postmenopause)
    prob *= STAGE_MULTIPLIER.get(p.stage, 0.6)

    # Race/ethnicity — SWAN data normalization
    prob *= RACE_HF_PREVALENCE.get(p.race, 0.60) / 0.65

    # BMI — insulation hypothesis
    if p.bmi >= 30:
        prob *= 1.25
    elif p.bmi >= 25:
        prob *= 1.10
    elif p.bmi < 18.5:
        prob *= 0.85

    # Age
    if p.age < 45:
        prob *= 0.7
    elif p.age > 60:
        prob *= 0.6

    # Smoking — advances menopause, increases VMS
    if p.smoking == "Current":
        prob *= 1.30
    elif p.smoking == "Former":
        prob *= 1.10

    # Alcohol
    if p.alcohol == "Heavy":
        prob *= 1.20
    elif p.alcohol == "Moderate":
        prob *= 1.05

    # Comorbidities
    if p.thyroid:
        prob *= 1.20
    if p.diabetes:
        prob *= 1.15
    if p.cardiovascular:
        prob *= 1.10

    # Medication thermoregulatory effect
    prob *= (1 + MED_THERMOREG_EFFECT.get(p.medication, 0))

    # Stress / mental health
    if p.stress == "High":
        prob *= 1.30
    elif p.stress == "Moderate":
        prob *= 1.10
    if p.mental_health:
        prob *= 1.10

    # Caffeine
    if p.caffeine == "Heavy":
        prob *= 1.15
    elif p.caffeine == "Moderate":
        prob *= 1.05

    # Exercise — mixed findings, slight protective effect
    if p.exercise == "High":
        prob *= 0.85
    elif p.exercise == "Sedentary":
        prob *= 1.15

    # Surgical menopause — abrupt estrogen withdrawal
    if p.surgical_menopause:
        prob *= 1.50

    return float(np.clip(prob, 0.01, 0.50))


def _compute_inter_threshold_zone(p: PatientProfile) -> float:
    """Compute inter-threshold zone width (°C).
    Symptomatic ≈ 0.0°C, asymptomatic ≈ 0.4°C.
    """
    itz = 0.4
    itz -= STAGE_MULTIPLIER.get(p.stage, 0.6) * 0.35
    if p.stress == "High":
        itz -= 0.05
    itz += MED_THERMOREG_EFFECT.get(p.medication, 0) * 0.15
    return float(np.clip(itz, -0.05, 0.45))


def _circadian_core_temp(hour_of_day: float) -> float:
    """Core body temperature circadian model. Peak ~18:00, trough ~04:00."""
    phase = ((hour_of_day - 18) / 24) * 2 * math.pi
    return 36.7 + 0.25 * math.cos(phase)


def _circadian_hr(hour_of_day: float, base_hr: float) -> float:
    """Resting heart rate circadian model. Peak ~14:00."""
    phase = ((hour_of_day - 14) / 24) * 2 * math.pi
    return base_hr + 8 * math.cos(phase)


# ═══════════════════════════════════════════════════════════════════════════════
# SINGLE-SUBJECT GENERATOR
# ═══════════════════════════════════════════════════════════════════════════════

def generate_subject(
    profile: PatientProfile,
    subject_id: int,
    duration_hours: int = 24,
    interval_sec: int = 30,
    seed: int = 42,
) -> Tuple[pd.DataFrame, dict]:
    """Generate a full continuous time series for one subject.

    Returns:
        (DataFrame, metadata_dict)
    """
    rng = np.random.default_rng(seed)
    hourly_prob = _compute_hourly_hf_probability(profile)
    itz = _compute_inter_threshold_zone(profile)
    n_samples = int((duration_hours * 3600) / interval_sec)

    # Base resting HR from age + fitness
    base_hr = 60 + (220 - profile.age - 60) * 0.35
    if profile.exercise == "High":
        base_hr -= 8
    elif profile.exercise == "Sedentary":
        base_hr += 5
    if profile.cardiovascular:
        base_hr += 4
    if profile.medication == "Beta Blockers":
        base_hr -= 12

    skin_temp_base = 33.5 + rng.normal(0, 0.3)

    # Pre-allocate arrays
    t_sec = np.arange(n_samples) * interval_sec
    hour_of_day = (t_sec / 3600) % 24

    skin_temp = np.full(n_samples, skin_temp_base)
    heart_rate = np.zeros(n_samples)
    core_temp_est = np.zeros(n_samples)
    hf_active = np.zeros(n_samples, dtype=np.int8)
    hf_severity = np.zeros(n_samples, dtype=np.int8)
    is_sleep = ((hour_of_day >= 23) | (hour_of_day < 6)).astype(np.int8)

    # Sensor noise
    skin_noise = rng.normal(0, 0.08, n_samples)
    hr_noise = rng.normal(0, 1.5, n_samples)
    core_noise = rng.normal(0, 0.05, n_samples)

    # Circadian baselines
    for i in range(n_samples):
        h = hour_of_day[i]
        core_temp_est[i] = _circadian_core_temp(h) + core_noise[i]
        heart_rate[i] = _circadian_hr(h, base_hr) + hr_noise[i]

    skin_temp += skin_noise

    # Sleep adjustments
    sleep_mask = is_sleep.astype(bool)
    skin_temp[sleep_mask] += 0.8
    heart_rate[sleep_mask] -= 6

    # BMI baseline shift
    if profile.bmi >= 30:
        skin_temp += 0.2

    # ── Flash event simulation ──
    in_flash = False
    flash_rem = 0
    flash_elapsed = 0
    flash_intensity = 0
    cool_rem = 0
    flash_onset_indices = []

    for i in range(n_samples):
        h = hour_of_day[i]
        core = core_temp_est[i]
        sw_thresh = 37.2 + itz + rng.normal(0, 0.03)

        # Initiation check
        if not in_flash and cool_rem <= 0:
            circ_mod = 1 + 0.3 * math.cos(((h - 18.4) / 24) * 2 * math.pi)
            sleep_mod = 0.58 if is_sleep[i] else 1.0
            p_sample = 1 - (1 - hourly_prob * circ_mod * sleep_mod) ** (interval_sec / 3600)
            therm_prox = 1.5 if core > (sw_thresh - 0.1) else 1.0

            if rng.random() < p_sample * therm_prox:
                in_flash = True
                dur = 60 + rng.random() * 240
                flash_rem = math.ceil(dur / interval_sec)
                flash_elapsed = 0
                # Severity 1–5 (expanded from 1–3)
                roll = rng.random()
                if roll < 0.15:
                    flash_intensity = 1   # very mild
                elif roll < 0.35:
                    flash_intensity = 2   # mild
                elif roll < 0.60:
                    flash_intensity = 3   # moderate
                elif roll < 0.82:
                    flash_intensity = 4   # severe
                else:
                    flash_intensity = 5   # very severe
                flash_onset_indices.append(i)

        if in_flash and flash_rem > 0:
            hf_active[i] = 1
            hf_severity[i] = flash_intensity
            total = flash_elapsed + flash_rem
            prog = flash_elapsed / total if total > 0 else 0

            # Skin temp rise: scaled to 0–5 severity
            temp_rise_max = flash_intensity * 0.55 + 0.3
            if prog < 0.3:
                envelope = prog / 0.3
            else:
                envelope = 1.0 - ((prog - 0.3) / 0.7) * 0.6
            skin_temp[i] += temp_rise_max * envelope

            # HR rise: precedes sweating onset
            hr_rise = flash_intensity * 2.5 + 2
            if prog < 0.15:
                hr_env = prog / 0.15
            elif prog < 0.5:
                hr_env = 1.0
            else:
                hr_env = 1.0 - ((prog - 0.5) / 0.5)
            heart_rate[i] += hr_rise * hr_env

            flash_elapsed += 1
            flash_rem -= 1
            if flash_rem <= 0:
                in_flash = False
                cool_rem = math.ceil((300 + rng.random() * 600) / interval_sec)

        if cool_rem > 0:
            cool_total = math.ceil(600 / interval_sec)
            cool_prog = 1 - (cool_rem / cool_total)
            skin_temp[i] += (1 - cool_prog) * 0.3
            cool_rem -= 1

    # Clamp HR
    heart_rate = np.clip(heart_rate, 40, 180).astype(int)

    # ── Compute regression target: time_to_next_hf ──
    time_to_next = np.full(n_samples, MAX_HORIZON_SEC, dtype=np.int32)
    for onset_idx in flash_onset_indices:
        for i in range(onset_idx, -1, -1):
            sec_until = (onset_idx - i) * interval_sec
            if sec_until > MAX_HORIZON_SEC:
                break
            if time_to_next[i] > sec_until:
                time_to_next[i] = sec_until

    # ── Build DataFrame ──
    df = pd.DataFrame({
        "subject_id": subject_id,
        "t_sec": t_sec,
        "hour": np.round(hour_of_day, 2),
        "skin_temp": np.round(skin_temp, 2),
        "heart_rate": heart_rate,
        "core_temp_est": np.round(core_temp_est, 2),
        "hf_active": hf_active,
        "hf_severity": hf_severity,
        "is_sleep": is_sleep,
        # Static features (encoded numerically)
        "s_age": profile.age,
        "s_bmi": round(profile.bmi, 1),
        "s_race": RACE_ENCODE.get(profile.race, 5),
        "s_stage": STAGE_ENCODE.get(profile.stage, 2),
        "s_smoking": SMOKE_ENCODE.get(profile.smoking, 0),
        "s_alcohol": ALCOHOL_ENCODE.get(profile.alcohol, 0),
        "s_medication": MED_ENCODE.get(profile.medication, 0),
        "s_stress": STRESS_ENCODE.get(profile.stress, 0),
        "s_caffeine": CAFFEINE_ENCODE.get(profile.caffeine, 0),
        "s_exercise": EXERCISE_ENCODE.get(profile.exercise, 0),
        "s_thyroid": int(profile.thyroid),
        "s_diabetes": int(profile.diabetes),
        "s_cardiovascular": int(profile.cardiovascular),
        "s_mental_health": int(profile.mental_health),
        "s_surgical": int(profile.surgical_menopause),
        # Target
        "time_to_next_hf": time_to_next,
    })

    meta = {
        "subject_id": subject_id,
        "n_flashes": len(flash_onset_indices),
        "hourly_prob": round(hourly_prob, 4),
        "itz": round(itz, 3),
        "profile": profile,
    }

    return df, meta


# ═══════════════════════════════════════════════════════════════════════════════
# COHORT GENERATOR
# ═══════════════════════════════════════════════════════════════════════════════

def generate_cohort(
    n_subjects: int = 200,
    duration_hours: int = 24,
    interval_sec: int = 30,
    seed: int = 42,
    train_pct: float = 0.70,
    val_pct: float = 0.15,
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, dict]:
    """Generate a full synthetic cohort with train/val/test splits.

    Splits are by subject ID (no data leakage).

    Returns:
        (train_df, val_df, test_df, full_df, summary_dict)
    """
    master_rng = np.random.default_rng(seed)
    dfs = []
    metas = []

    for s in range(n_subjects):
        profile = random_profile(master_rng)
        s_seed = int(master_rng.integers(0, 2**31))
        df, meta = generate_subject(profile, s, duration_hours, interval_sec, s_seed)
        dfs.append(df)
        metas.append(meta)

    full_df = pd.concat(dfs, ignore_index=True)

    # Subject-level split
    n_train = round(n_subjects * train_pct)
    n_val = round(n_subjects * val_pct)

    train_ids = set(range(0, n_train))
    val_ids = set(range(n_train, n_train + n_val))
    # test = remainder

    train_df = full_df[full_df["subject_id"].isin(train_ids)].reset_index(drop=True)
    val_df = full_df[full_df["subject_id"].isin(val_ids)].reset_index(drop=True)
    test_df = full_df[~full_df["subject_id"].isin(train_ids | val_ids)].reset_index(drop=True)

    total_flashes = sum(m["n_flashes"] for m in metas)
    summary = {
        "n_subjects": n_subjects,
        "duration_hours": duration_hours,
        "interval_sec": interval_sec,
        "total_rows": len(full_df),
        "total_hot_flashes": total_flashes,
        "avg_flashes_per_subject": round(total_flashes / n_subjects, 2),
        "avg_rate_per_hour": round(total_flashes / (n_subjects * duration_hours), 3),
        "n_columns": len(full_df.columns),
        "split": {
            "train": {"n_subjects": n_train, "n_rows": len(train_df)},
            "val": {"n_subjects": n_val, "n_rows": len(val_df)},
            "test": {"n_subjects": n_subjects - n_train - n_val, "n_rows": len(test_df)},
        },
        "severity_distribution": full_df[full_df["hf_severity"] > 0]["hf_severity"]
            .value_counts().sort_index().to_dict(),
        "subject_metas": metas,
    }

    return train_df, val_df, test_df, full_df, summary


# ═══════════════════════════════════════════════════════════════════════════════
# COLUMN REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

COLUMN_SCHEMA = {
    "subject_id":       "int    — unique subject identifier",
    "t_sec":            "int    — elapsed seconds from start",
    "hour":             "float  — hour of day (0–24)",
    "skin_temp":        "float  — wrist skin temperature °C",
    "heart_rate":       "int    — beats per minute",
    "core_temp_est":    "float  — estimated core temperature °C",
    "hf_active":        "0/1   — currently in a hot flash",
    "hf_severity":      "0–5   — 0=none, 1=very mild, 2=mild, 3=moderate, 4=severe, 5=very severe",
    "is_sleep":         "0/1   — sleep period (23:00–06:00)",
    "s_age":            "int    — age at signup",
    "s_bmi":            "float  — body mass index",
    "s_race":           "0–5   — encoded ethnicity",
    "s_stage":          "0–4   — encoded menopause stage",
    "s_smoking":        "0–2   — never/former/current",
    "s_alcohol":        "0–3   — none/light/moderate/heavy",
    "s_medication":     "0–9   — medication class index",
    "s_stress":         "0–2   — low/moderate/high",
    "s_caffeine":       "0–3   — none to heavy",
    "s_exercise":       "0–3   — sedentary to high",
    "s_thyroid":        "0/1",
    "s_diabetes":       "0/1",
    "s_cardiovascular": "0/1",
    "s_mental_health":  "0/1",
    "s_surgical":       "0/1   — surgical menopause",
    "time_to_next_hf":  "int    — TARGET: seconds until next hot flash (max 7200)",
}


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN — demo run
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    print("Generating cohort: 200 subjects × 24h @ 30s intervals...\n")

    train_df, val_df, test_df, full_df, summary = generate_cohort(
        n_subjects=200, duration_hours=24, interval_sec=30, seed=42
    )

    print(f"{'='*60}")
    print(f"  COHORT SUMMARY")
    print(f"{'='*60}")
    print(f"  Subjects:           {summary['n_subjects']}")
    print(f"  Total rows:         {summary['total_rows']:,}")
    print(f"  Total hot flashes:  {summary['total_hot_flashes']}")
    print(f"  Avg per subject:    {summary['avg_flashes_per_subject']}")
    print(f"  Avg rate:           {summary['avg_rate_per_hour']}/hour")
    print(f"  Columns:            {summary['n_columns']}")
    print(f"  Severity dist:      {summary['severity_distribution']}")
    print(f"{'─'*60}")
    print(f"  Train: {summary['split']['train']['n_subjects']} subjects, "
          f"{summary['split']['train']['n_rows']:,} rows")
    print(f"  Val:   {summary['split']['val']['n_subjects']} subjects, "
          f"{summary['split']['val']['n_rows']:,} rows")
    print(f"  Test:  {summary['split']['test']['n_subjects']} subjects, "
          f"{summary['split']['test']['n_rows']:,} rows")
    print(f"{'='*60}\n")

    print("── full_df.head(10) ──")
    print(full_df.head(10).to_string(index=False))
    print()
    print("── full_df.dtypes ──")
    print(full_df.dtypes)
    print()
    print("── full_df.describe() ──")
    print(full_df.describe().round(2).to_string())
    print()

    # Show a hot flash event
    flash_rows = full_df[full_df["hf_active"] == 1]
    if len(flash_rows) > 0:
        first_flash_subj = flash_rows.iloc[0]["subject_id"]
        first_flash_t = flash_rows.iloc[0]["t_sec"]
        window = full_df[
            (full_df["subject_id"] == first_flash_subj) &
            (full_df["t_sec"] >= first_flash_t - 120) &
            (full_df["t_sec"] <= first_flash_t + 300)
        ]
        print(f"── Hot flash event (subject {int(first_flash_subj)}) ──")
        print(window[["t_sec","hour","skin_temp","heart_rate","hf_active",
                       "hf_severity","time_to_next_hf"]].to_string(index=False))

    # Save to CSV
    full_df.to_csv("/home/claude/hf_full_dataset.csv", index=False)
    train_df.to_csv("/home/claude/hf_train.csv", index=False)
    val_df.to_csv("/home/claude/hf_val.csv", index=False)
    test_df.to_csv("/home/claude/hf_test.csv", index=False)
    print("\nCSVs saved to /home/claude/")
