"""
Generates realistic sample retail source files that mimic the feeds the
real business systems (POS, e-commerce, CRM, WMS) would eventually deliver.
Column names/types are the CONTRACT - swapping this generator for real
extracts later requires no changes downstream (staging/intermediate/marts).

Run: python generate_sample_data.py
Output: customers.csv, products.csv, stores.csv, orders.csv, order_items.csv,
        inventory_snapshots.csv  (written next to this script)
"""
import csv
import os
import random
from datetime import date, datetime, timedelta

random.seed(42)  # reproducible sample data

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

FIRST_NAMES = ["James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda",
               "David", "Elizabeth", "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
               "Thomas", "Sarah", "Charles", "Karen", "Ananya", "Rahul", "Priya", "Arjun", "Wei",
               "Mei", "Carlos", "Sofia", "Liam", "Olivia"]
LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
              "Rodriguez", "Martinez", "Wilson", "Anderson", "Taylor", "Thomas", "Moore", "Jackson",
              "Patel", "Kumar", "Sharma", "Chen", "Wang", "Nguyen", "Kim", "Lee", "Silva", "Costa"]
CITIES = [("New York", "NY"), ("Los Angeles", "CA"), ("Chicago", "IL"), ("Houston", "TX"),
          ("Phoenix", "AZ"), ("Philadelphia", "PA"), ("San Antonio", "TX"), ("San Diego", "CA"),
          ("Dallas", "TX"), ("Austin", "TX"), ("Seattle", "WA"), ("Denver", "CO"), ("Boston", "MA"),
          ("Atlanta", "GA"), ("Miami", "FL")]
LOYALTY_TIERS = ["BRONZE", "SILVER", "GOLD", "PLATINUM"]

CATEGORIES = {
    "Apparel": ["Men's Wear", "Women's Wear", "Kids Wear", "Footwear"],
    "Electronics": ["Mobile Accessories", "Audio", "Computing", "Wearables"],
    "Home & Kitchen": ["Cookware", "Storage", "Small Appliances", "Decor"],
    "Grocery": ["Snacks", "Beverages", "Dairy", "Packaged Foods"],
    "Beauty": ["Skincare", "Haircare", "Makeup", "Fragrance"],
}
BRANDS = ["Northfield", "Cascade", "Urban Edge", "Bluepeak", "Everline", "Solace", "Meridian",
          "Ashgrove", "Tidal", "Vanta"]

STORE_REGIONS = {
    "Northeast": ["New York, NY", "Boston, MA", "Philadelphia, PA"],
    "West": ["Los Angeles, CA", "Seattle, WA", "San Diego, CA"],
    "South": ["Houston, TX", "Dallas, TX", "Austin, TX", "Atlanta, GA", "Miami, FL"],
    "Midwest": ["Chicago, IL", "Denver, CO"],
}

PAYMENT_METHODS = ["CREDIT_CARD", "DEBIT_CARD", "GIFT_CARD", "PAYPAL", "STORE_CREDIT"]
ORDER_STATUSES = ["COMPLETED", "COMPLETED", "COMPLETED", "COMPLETED", "CANCELLED", "REFUNDED", "PENDING"]

TODAY = date(2026, 8, 13)


def rand_datetime_between(start: date, end: date) -> datetime:
    delta_days = (end - start).days
    d = start + timedelta(days=random.randint(0, max(delta_days, 0)))
    return datetime.combine(d, datetime.min.time()) + timedelta(
        hours=random.randint(8, 21), minutes=random.randint(0, 59), seconds=random.randint(0, 59)
    )


def gen_customers(n=500):
    rows = []
    for i in range(1, n + 1):
        fn, ln = random.choice(FIRST_NAMES), random.choice(LAST_NAMES)
        city, state = random.choice(CITIES)
        signup = rand_datetime_between(TODAY - timedelta(days=1095), TODAY - timedelta(days=1))
        updated = signup + timedelta(days=random.randint(0, (TODAY - signup.date()).days))
        rows.append({
            "customer_id": f"CUST{i:06d}",
            "first_name": fn,
            "last_name": ln,
            "email": f"{fn.lower()}.{ln.lower()}{i}@example.com",
            "phone": f"+1-{random.randint(200,999)}-{random.randint(200,999)}-{random.randint(1000,9999)}",
            "address_line1": f"{random.randint(100,9999)} {random.choice(['Main St','Oak Ave','Elm St','Maple Dr','2nd Ave'])}",
            "city": city,
            "state": state,
            "postal_code": f"{random.randint(10000,99999)}",
            "country": "USA",
            "loyalty_tier": random.choices(LOYALTY_TIERS, weights=[45, 30, 18, 7])[0],
            "signup_date": signup.strftime("%Y-%m-%d"),
            "updated_at": updated.strftime("%Y-%m-%d %H:%M:%S"),
        })
    return rows


def gen_products(n=200):
    rows = []
    for i in range(1, n + 1):
        category = random.choice(list(CATEGORIES.keys()))
        subcategory = random.choice(CATEGORIES[category])
        brand = random.choice(BRANDS)
        unit_cost = round(random.uniform(3.0, 180.0), 2)
        margin = random.uniform(1.3, 2.8)
        unit_price = round(unit_cost * margin, 2)
        created = rand_datetime_between(TODAY - timedelta(days=1095), TODAY - timedelta(days=30))
        updated = created + timedelta(days=random.randint(0, 200))
        rows.append({
            "product_id": f"PROD{i:06d}",
            "sku": f"SKU-{category[:3].upper()}-{i:05d}",
            "product_name": f"{brand} {subcategory} {random.choice(['Classic','Pro','Everyday','Signature','Lite'])} {i}",
            "category": category,
            "subcategory": subcategory,
            "brand": brand,
            "unit_cost": unit_cost,
            "unit_price": unit_price,
            "is_active": random.choices(["TRUE", "FALSE"], weights=[92, 8])[0],
            "created_at": created.strftime("%Y-%m-%d %H:%M:%S"),
            "updated_at": updated.strftime("%Y-%m-%d %H:%M:%S"),
        })
    return rows


def gen_stores(n=15):
    rows = []
    store_id = 1
    for region, city_states in STORE_REGIONS.items():
        for city_state in city_states:
            city, state = city_state.split(", ")
            store_type = "ONLINE" if store_id == 1 else "PHYSICAL"
            open_date = rand_datetime_between(TODAY - timedelta(days=1800), TODAY - timedelta(days=200)).date()
            rows.append({
                "store_id": f"STORE{store_id:04d}",
                "store_name": "RetailCo E-Commerce" if store_type == "ONLINE" else f"RetailCo {city}",
                "store_type": store_type,
                "region": region,
                "city": city,
                "state": state,
                "country": "USA",
                "open_date": open_date.strftime("%Y-%m-%d"),
                "updated_at": TODAY.strftime("%Y-%m-%d %H:%M:%S"),
            })
            store_id += 1
            if store_id > n:
                break
        if store_id > n:
            break
    return rows


def gen_orders_and_items(customers, products, stores, n_orders=5000):
    active_products = [p for p in products if p["is_active"] == "TRUE"]
    order_rows = []
    item_rows = []
    order_item_seq = 1
    start_date = TODAY - timedelta(days=180)

    for i in range(1, n_orders + 1):
        cust = random.choice(customers)
        store = random.choice(stores)
        order_dt = rand_datetime_between(start_date, TODAY)
        status = random.choice(ORDER_STATUSES)
        updated = order_dt + timedelta(hours=random.randint(0, 72))

        order_rows.append({
            "order_id": f"ORD{i:07d}",
            "customer_id": cust["customer_id"],
            "store_id": store["store_id"],
            "order_date": order_dt.strftime("%Y-%m-%d %H:%M:%S"),
            "order_status": status,
            "payment_method": random.choice(PAYMENT_METHODS),
            "currency": "USD",
            "updated_at": updated.strftime("%Y-%m-%d %H:%M:%S"),
        })

        n_lines = random.choices([1, 2, 3, 4, 5], weights=[35, 30, 20, 10, 5])[0]
        chosen_products = random.sample(active_products, k=min(n_lines, len(active_products)))
        for prod in chosen_products:
            qty = random.choices([1, 2, 3, 4], weights=[60, 25, 10, 5])[0]
            unit_price = prod["unit_price"]
            discount_pct = random.choices([0, 0, 0, 5, 10, 15, 20], weights=[50, 15, 10, 10, 8, 4, 3])[0]
            discount_amount = round(unit_price * qty * discount_pct / 100.0, 2)
            line_total = round(unit_price * qty - discount_amount, 2)
            item_rows.append({
                "order_item_id": f"OI{order_item_seq:08d}",
                "order_id": order_rows[-1]["order_id"],
                "product_id": prod["product_id"],
                "quantity": qty,
                "unit_price": unit_price,
                "discount_amount": discount_amount,
                "line_total": line_total,
                "updated_at": updated.strftime("%Y-%m-%d %H:%M:%S"),
            })
            order_item_seq += 1

    return order_rows, item_rows


def gen_inventory_snapshots(products, stores, days=30):
    physical_stores = [s for s in stores if s["store_type"] == "PHYSICAL"]
    rows = []
    active_products = [p for p in products if p["is_active"] == "TRUE"]
    sampled_products = random.sample(active_products, k=min(60, len(active_products)))

    for d in range(days):
        snap_date = TODAY - timedelta(days=days - 1 - d)
        for store in physical_stores:
            for prod in sampled_products:
                qty_on_hand = random.randint(0, 250)
                qty_reserved = random.randint(0, min(20, qty_on_hand)) if qty_on_hand else 0
                rows.append({
                    "snapshot_date": snap_date.strftime("%Y-%m-%d"),
                    "store_id": store["store_id"],
                    "product_id": prod["product_id"],
                    "quantity_on_hand": qty_on_hand,
                    "quantity_reserved": qty_reserved,
                    "reorder_point": 25,
                    "updated_at": datetime.combine(snap_date, datetime.min.time()).strftime("%Y-%m-%d %H:%M:%S"),
                })
    return rows


def write_csv(filename, rows, fieldnames):
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows):>7,} rows -> {path}")


def main():
    customers = gen_customers(500)
    products = gen_products(200)
    stores = gen_stores(15)
    orders, order_items = gen_orders_and_items(customers, products, stores, n_orders=5000)
    inventory = gen_inventory_snapshots(products, stores, days=30)

    write_csv("customers.csv", customers, list(customers[0].keys()))
    write_csv("products.csv", products, list(products[0].keys()))
    write_csv("stores.csv", stores, list(stores[0].keys()))
    write_csv("orders.csv", orders, list(orders[0].keys()))
    write_csv("order_items.csv", order_items, list(order_items[0].keys()))
    write_csv("inventory_snapshots.csv", inventory, list(inventory[0].keys()))


if __name__ == "__main__":
    main()
