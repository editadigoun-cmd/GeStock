# GeStock

GeStock is a premium, offline-first business management app for independent businesses and multi-company operators.

## Product principles
- One account can manage several independent businesses, including different business types.
- Mobile-first experience for Android and iOS.
- Offline-first workflows with reliable, idempotent synchronization.
- Modular features: products, inventory, sales, purchasing, customers, suppliers, cash, expenses and reporting.
- Premium Emerald Intelligence visual identity.

## Repository structure
- `mobile/`: Flutter mobile application.
- `docs/`: product, architecture and engineering decisions.
- `backend/`: API and database implementation (next implementation phase).

## Current status
The initial Flutter application foundation and premium dashboard are being established. The Neon PostgreSQL project and first database migration are already provisioned separately.

## Run the mobile app
```bash
cd mobile
flutter pub get
flutter run
```

See [the architecture guide](docs/ARCHITECTURE.md) for the implementation direction.
