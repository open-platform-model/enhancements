<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Contract and schema

- [ ] 1.1 core: add the tombstone definition, the catalog's removed map, the promotion field on resources, traits and blueprints, the promotion and tombstone shape checks, and the specification text for each

## 2. Publish rules

- [ ] 2.1 cli: refuse a removal with no tombstone or a dropped tombstone, refuse a tombstone for an alpha key, and refuse one whose replacement has not been published for the floor
- [ ] 2.2 cli: compare a promotion with its origin level, refuse a promotion that changes shape, and report lifecycle state in the registry check

## 3. Catalog

- [ ] 3.1 catalog_opm: author the tombstone map and make the first real promotion as the proof case

## 4. Documentation

- [ ] 4.1 opmodel.dev: document the level ladder, promotion and retirement
