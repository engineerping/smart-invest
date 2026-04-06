#!/usr/bin/env python3
"""
Seed NAV history for all funds.
Generates realistic weekday NAV values for the past N years.
"""
import random
import psycopg2
from datetime import date, timedelta

YEARS = 5
START_NAV = {
    'SI-MM-01': 10.0,
    'SI-BI-01': 12.5,
    'SI-BI-02': 11.8,
    'SI-EI-01': 25.0,
    'SI-EI-02': 18.0,
    'SI-EI-03': 22.0,
    'SI-MA-01': 10.0,
    'SI-MA-02': 10.5,
    'SI-MA-03': 11.0,
    'SI-MA-04': 12.0,
    'SI-MA-05': 13.0,
}

def is_weekday(d):
    return d.weekday() < 5  # Mon-Fri

def generate_nav_series(start_nav, days):
    nav = start_nav
    for i in range(days):
        delta = random.uniform(-0.005, 0.005)  # ±0.5%
        nav = nav * (1 + delta)
        yield round(nav, 4)

def main():
    conn = psycopg2.connect(
        host='localhost',
        dbname='smartinvest',
        user='smartadmin',
        password='localdev_only'
    )
    cur = conn.cursor()

    for code, start_nav in START_NAV.items():
        # Get fund_id
        cur.execute("SELECT id FROM funds WHERE code = %s", (code,))
        row = cur.fetchone()
        if not row:
            print(f"Fund {code} not found, skipping")
            continue
        fund_id = row[0]

        # Generate dates
        end = date.today()
        start = end - timedelta(days=365 * YEARS)
        dates = [start + timedelta(days=i) for i in range((end - start).days + 1)]
        weekdays = [d for d in dates if is_weekday(d)]

        # Generate NAV series
        nav_values = list(generate_nav_series(start_nav, len(weekdays)))

        # Insert
        for d, nav in zip(weekdays, nav_values):
            cur.execute(
                "INSERT INTO fund_nav_history (fund_id, nav, nav_date) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
                (fund_id, nav, d)
            )
        print(f"{code}: inserted {len(weekdays)} NAV records (start nav: {start_nav})")

    conn.commit()
    cur.close()
    conn.close()
    print("Done.")

if __name__ == '__main__':
    main()