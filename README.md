# Allocation App (Flutter 3.29.3) — Page 2

This project is built for the Allocation Problem assignment using:
- Flutter 3.29.3
- BLoC (flutter_bloc)
- Mock data only

## What "Page 2" adds (on top of Page 1)
✅ Manual allocation editor (per order):
- Add/remove allocation lines
- Pick Warehouse + Supplier (respect WH-000 / SP-000 wildcard rules)
- Enter quantity with 2 decimals
- Validations:
  - Total allocated <= requested
  - Stock availability (cannot exceed remaining stock, but allows reusing the order’s current allocation)
  - Customer credit availability (cannot exceed remaining credit, but allows reusing the order’s current spend)
- Save updates the global remaining stock + remaining customer credit

## Run
```bash
flutter pub get
flutter run
```

## Next pages you can ask me for
- Page 3: Performance polish (Isolate.run for 10k+ orders, BlocSelector)
- Page 4: Tests (bloc_test + allocation engine & manual validation tests)
