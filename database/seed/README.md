# Seed data

Demo rows used to populate a fresh AgriPulse database. The loader lives in the
backend ([`backend/app/seed.py`](../../backend/app/seed.py)) because it needs the
ORM to hash passwords and resolve foreign keys; these CSVs are its input.

Run it (with PostgreSQL up and the DB created):

```bash
cd backend && source .venv/bin/activate
python -m app.seed            # idempotent — skips rows whose unique key exists
python -m app.seed --reset    # drop all tables, recreate, reseed
```

The farmer/seller accounts share the password **`Pass1234`**; the analyst uses
its own seeded credential.

| File | Loads | Notes |
|------|-------|-------|
| `regions.csv`      | `regions`      | 8 regions (divisions); seeded first |
| `users.csv`        | `users`        | farmers · sellers · the analyst; passwords hashed on load |
| `farmers.csv`      | `farmers`      | farm profiles, linked to farmer users |
| `crop_history.csv` | `crop_history` | also appended to live when a farmer logs a crop |
| `products.csv`     | `products`     | seller catalogue |
| `orders.csv`       | `orders`       | farmer → product orders |
| `posts.csv`        | `posts`        | community feed |
| `comments.csv`     | `comments`     | replies on posts |
| `broadcasts.csv`   | `broadcasts`   | analyst disaster broadcasts (flood, cyclone, pest, disease) |

Load order matters (foreign keys): regions → users → farmers → products →
everything else. `seed.py` handles that ordering for you.
