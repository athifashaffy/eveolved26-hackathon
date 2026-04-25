"""Aggregate Baigutanova data into a compact JSON for the Flutter app.

Output: app/assets/data/trends.json
Structure:
  {
    "subjects": [
      {
        "id": "ab60",
        "sex": "F", "age": 24,
        "phq9": {"baseline": 4, "mid": 2, "final": 3},
        "days": [
          {"date": "2021-03-09", "rmssd": 42.1, "sdnn": 55.2, "hr": 72.4,
           "lfhf": 1.2, "steps": 6200,
           "sleep_h": 6.5, "sleep_eff": 0.87, "sleep_lat_h": 1.0, "waso": 0.0}
        ]
      }
    ]
  }
"""
import json
import os
import pandas as pd

DATA_DIR = "/Users/baljinder/StudioProjects/eveolved26-hackathon/data"
OUT_PATH = "/Users/baljinder/StudioProjects/eveolved26-hackathon/app/assets/data/trends.json"
N_SUBJECTS = 6  # bundle a handful so app can swap


def load():
    survey = pd.read_csv(os.path.join(DATA_DIR, "survey.csv"))
    sleep = pd.read_csv(os.path.join(DATA_DIR, "sleep_diary.csv"))
    hrv = pd.read_csv(os.path.join(DATA_DIR, "sensor_hrv_filtered.csv"))
    return survey, sleep, hrv


def aggregate_hrv_daily(hrv: pd.DataFrame) -> pd.DataFrame:
    hrv = hrv.copy()
    hrv["date"] = pd.to_datetime(hrv["ts_start"], unit="ms").dt.strftime("%Y-%m-%d")
    agg = hrv.groupby(["deviceId", "date"]).agg(
        rmssd=("rmssd", "mean"),
        sdnn=("sdnn", "mean"),
        hr=("HR", "mean"),
        lfhf=("lf/hf", "mean"),
        steps=("steps", "sum"),
    ).reset_index()
    return agg


def pick_subjects(survey: pd.DataFrame, hrv_daily: pd.DataFrame, sleep: pd.DataFrame, n: int):
    coverage = hrv_daily.groupby("deviceId").size().rename("hrv_days")
    sleep_cov = sleep.groupby("userId").size().rename("sleep_days")
    df = survey.set_index("deviceId").join(coverage).join(sleep_cov)
    df = df.dropna(subset=["hrv_days", "sleep_days", "PHQ9_1"])
    df = df.sort_values(["hrv_days", "sleep_days"], ascending=False)
    return df.head(n).index.tolist()


def build_subject(sid, survey, hrv_daily, sleep):
    meta = survey[survey.deviceId == sid].iloc[0]
    h = hrv_daily[hrv_daily.deviceId == sid].copy()
    s = sleep[sleep.userId == sid].copy()
    merged = h.merge(s, left_on="date", right_on="date", how="outer").sort_values("date")
    days = []
    for _, r in merged.iterrows():
        days.append({
            "date": r.get("date"),
            "rmssd": _num(r.get("rmssd")),
            "sdnn": _num(r.get("sdnn")),
            "hr": _num(r.get("hr")),
            "lfhf": _num(r.get("lfhf")),
            "steps": _num(r.get("steps")),
            "sleep_h": _num(r.get("sleep_duration")),
            "sleep_eff": _num(r.get("sleep_efficiency")),
            "sleep_lat_h": _num(r.get("sleep_latency")),
            "waso": _num(r.get("waso")),
        })
    return {
        "id": sid,
        "sex": str(meta.get("sex", "")),
        "age": _num(meta.get("age")),
        "phq9": {
            "baseline": _num(meta.get("PHQ9_1")),
            "mid": _num(meta.get("PHQ9_2")),
            "final": _num(meta.get("PHQ9_F")),
        },
        "days": days,
    }


def _num(v):
    try:
        if pd.isna(v):
            return None
        f = float(v)
        return round(f, 3)
    except Exception:
        return None


def main():
    survey, sleep, hrv = load()
    hrv_daily = aggregate_hrv_daily(hrv)
    subjects = pick_subjects(survey, hrv_daily, sleep, N_SUBJECTS)
    print(f"Selected subjects: {subjects}")
    out = {"subjects": [build_subject(sid, survey, hrv_daily, sleep) for sid in subjects]}
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w") as f:
        json.dump(out, f)
    size = os.path.getsize(OUT_PATH)
    print(f"Wrote {OUT_PATH} ({size/1024:.1f} KB), {sum(len(s['days']) for s in out['subjects'])} total days")


if __name__ == "__main__":
    main()
