# CloudKit schema

`schema.ckdb` is the Production schema of `iCloud.codes.tim.Zili`, exported with
`cktool`. Production builds (TestFlight and the App Store) cannot create record
types or fields, so any change to a `@Model` has to reach Production before the
build that carries it ships. Otherwise its records never leave the device.

## Changing the schema

1. Write the new model to Development. Run a Debug build on a Mac signed into
   iCloud with `-initializeCloudKitSchema`. It uploads a sample of every record
   type and field, then exits before opening the app's store:

   ```sh
   path/to/Debug/Zili.app/Contents/MacOS/Zili -initializeCloudKitSchema
   ```

2. Deploy it. In CloudKit Console, open Development and choose **Deploy Schema
   Changes**. The diff should show only additions: Production is append-only,
   and a deployed field can never be renamed or removed.

3. Export Production over `schema.ckdb` and commit it:

   ```sh
   xcrun cktool export-schema --team-id 2NFSK2WB24 \
     --container-id iCloud.codes.tim.Zili --environment production \
     --token "$(~/Repositories/certificates/bin/cloudkit-token)" \
     --output-file CloudKit/schema.ckdb
   ```

The management token lives encrypted in the certificates repository. See its
`SETUP.md`.

## How it's checked

- **`ZiliTests/CloudKitSchemaTests`** compares `schema.ckdb` with the models the
  app syncs (`ZiliApp.syncedModels`). A missing record type or field, or a field
  of the wrong type, is a test warning, so a model change can be built before
  its schema is deployed.
- **The CloudKit workflow** exports Production on every push, pull request, and
  Monday, and fails unless it matches `schema.ckdb`. A failure means someone
  deployed without exporting (re-run step 3) or edited the file by hand.
- **The release workflow** runs both checks first, with the schema test strict,
  and archives nothing if either fails: a model change has to complete all three
  steps above before it ships.

Don't reset Development to start over. `cktool reset-schema` also deletes
TipKit's `CD_CoreTipRecord`, which the schema writer can't recreate because only
TipKit writes it.
