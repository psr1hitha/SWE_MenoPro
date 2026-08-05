# SWE_MenoPro

MenoPro is an end-to-end system that predicts hot flashes in real time by fusing wearable biometric data with machine learning, and surfaces those predictions to users through a native iOS app.

---

## Overview

Menopause-related hot flashes are difficult to anticipate, which limits users' ability to prepare or manage symptoms proactively. MenoPro addresses this by:

- Streaming biometric signals (temperature, EDA, heart rate) from custom Arduino hardware
- Processing and normalizing high-frequency time-series data in real time
- Predicting **time-to-next-hot-flash** using a trained ML model
- Delivering predictions to users through a secure, real-time iOS app

---

## Key Contributions:

### iOS Frontend
- Built the Swift-based iOS application from the ground up
- Integrated **Firebase Authentication** for secure, per-user login
- Designed real-time UI to display live risk predictions as they're generated

### Data Pipeline
- Architected an end-to-end time-series pipeline processing **50,000+ biometric readings per session**
- Handled ingestion, cleaning, and real-time normalization of temperature, EDA (electrodermal activity), and heart rate signals from Arduino hardware
- Designed for low-latency streaming to support real-time ML inference

### Signal Engineering
- Engineered **proxy skin conductance features** via multivariate signal fusion
- Enabled hot flash prediction **without dedicated GSR sensors**
- Reduced hardware cost by **~60%** while maintaining model accuracy — a key unlock for affordability and scalability

### Machine Learning
- Trained a **random forest regressor** to predict time-to-next-hot-flash
- Engineered features included:
  - Lag features
  - Delta (rate-of-change) signals
  - Rolling statistical windows
- Achieved **86.3% accuracy** across **1,200+ labeled validation events**

---

## System Architecture

```
Arduino Hardware (Temp, EDA, HR sensors)
        │
        ▼
Real-Time Data Pipeline (ingestion → normalization → feature engineering)
        │
        ▼
ML Inference (Random Forest Regressor — time-to-next-hot-flash)
        │
        ▼
Firebase (Auth + real-time data sync)
        │
        ▼
iOS App (Swift) — live risk predictions displayed to user
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Hardware | Arduino (temperature, EDA, heart rate sensors) |
| Data Pipeline | Time-series ingestion & normalization (custom-built) |
| ML | Random Forest Regressor (scikit-learn) |
| Backend / Auth | Firebase |
| Mobile Frontend | Swift (iOS) |

---

## Impact

- **~60% reduction** in hardware cost by replacing GSR sensors with engineered proxy features
- **86.3% prediction accuracy** validated across 1,200+ labeled events
- Delivered a fully functional, real-time end-to-end system from sensor to screen

---
