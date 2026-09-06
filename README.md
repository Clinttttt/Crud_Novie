# Grocery Inventory System

A stock tracker for a small store (sari-sari store / mini-mart). It keeps track of how many
units of each product are on the shelf, what they cost, and when they expire, so nothing runs
out or expires without anyone noticing.

This is a CRUD app split into two parts that talk over a REST API:

| Part | Folder | Technology |
| --- | --- | --- |
| Server (REST API) | `Grocery.Api` | ASP.NET Core on .NET 8, EF Core, PostgreSQL |
| Client (web UI) | `Grocery.Client` | Angular |

The four CRUD operations, in store terms:

- **Create** — record a delivery, e.g. 50 cans of sardines with wholesale price, retail price and expiry date.
- **Read** — see current stock levels, list only the items running low, or search a product by name or barcode.
- **Update** — change a price, or lower the quantity after items are sold or damaged.
- **Delete** — remove a product line the store no longer sells.

---

## The easy way: run `start.bat`

If you are on Windows, you do not have to follow the steps below one by one. Download the
code, then **double-click `start.bat`** in the project folder. It does everything:

1. Checks for the .NET SDK, Node.js and PostgreSQL, and offers to install anything missing.
2. Tests the PostgreSQL password and asks you for it if the saved one does not work. Your
   answer is stored outside the project, so it never ends up on GitHub.
3. Runs `npm install`, but only the first time — later runs skip it.
4. Builds and starts the API, starts the web app, and opens the page in your browser.

It is safe to run again any time; anything already done is detected and skipped. Two windows
open, *Grocery API* and *Grocery Web App* — close them to stop the app.

If something else on your PC already uses port 4200, run it from a terminal with a different
port instead:

```bash
.\start.bat -ClientPort 4300
```

The rest of this README explains the same steps by hand, in case you want to do it yourself or
the script runs into something it cannot fix.

---

## 1. Install what you need

You only have to do this part once. If you already have any of these, skip it.
`start.bat` can install them for you, so this section is only for doing it by hand.

### .NET 8 SDK

Download the **SDK** (not just the runtime) from
<https://dotnet.microsoft.com/download/dotnet/8.0> and run the installer.

Check it afterwards in a new terminal:

```bash
dotnet --version
```

You should see a version starting with `8.` (a newer SDK such as 9 or 10 also works — the
project is pinned to .NET 8, but it can run on newer runtimes).

### Node.js

Download the **LTS** version from <https://nodejs.org> and run the installer. This is what
runs the Angular client. Check it:

```bash
node -v
npm -v
```

Node 22.22.3 or newer is required (the current LTS download is fine). Angular refuses to
start on anything older.

### PostgreSQL

Download it from <https://www.postgresql.org/download/> and run the installer.

During installation:

1. Keep the default port `5432`.
2. **Write down the password you set for the `postgres` user.** You will need it in step 3.
3. Leave the rest at their defaults. pgAdmin is installed too, which is a handy way to look
   at the data later, but it is not required.

When the installer finishes, PostgreSQL runs in the background as a Windows service, so there
is nothing to start manually.

---

## 2. Get the code

```bash
git clone <the GitHub URL of this repository>
cd CRUD_NOVIE
```

---

## 3. Tell the API your PostgreSQL password

Open `Grocery.Api/appsettings.Development.json`. It looks like this:

```json
"ConnectionStrings": {
  "DefaultConnection": "Host=localhost;Port=5432;Database=grocerycrud;Username=postgres;Password=postgres"
}
```

Change `Password=postgres` to the password you set when installing PostgreSQL. If you kept
the username `postgres` and port `5432`, nothing else needs to change.

You do **not** need to create the database yourself. The first time the API starts it creates
the `grocerycrud` database and its `Products` table automatically.

---

## 4. Run it

You need **two terminals** open at the same time, both in the project folder.

### Terminal 1 — the API

```bash
dotnet run --project Grocery.Api
```

Wait for `Now listening on: http://localhost:5199`. Leave this terminal running.

To check it works, open <http://localhost:5199/swagger> in your browser. That page lists every
endpoint and lets you try them directly.

### Terminal 2 — the web app

```bash
cd Grocery.Client
npm install
npm start
```

`npm install` downloads the Angular packages and only needs to be done once (it takes a few
minutes the first time). When it says it is listening, open <http://localhost:4200>.

That's it. Add a product in the form and it is saved to PostgreSQL through the API.

To stop either one, press `Ctrl+C` in its terminal.

---

## 5. Using the app

- **Add product** — fill in the form and press *Add product*. Name and barcode are required;
  the barcode has to be unique because it identifies the product line.
- **Reorder level** — the app flags an item as *Low* once its quantity drops to this number.
  For example, set it to 12 and the item is flagged when 12 or fewer are left.
- **Search** — type part of a product name or a barcode. Results update as you type.
- **Running low / Expiring** — the tabs above the table. *Expiring* shows items that are
  already expired or expire within 30 days.
- **Edit** — press *Edit* on a row, change the values in the form, then *Save changes*. This
  is how you record a price increase, or a lower quantity after a sale.
- **Delete** — press *Delete* on a row and confirm.

---

## The REST API

Base address: `http://localhost:5199/api/products`

| Method | Path | What it does |
| --- | --- | --- |
| `GET` | `/api/products` | The whole inventory |
| `GET` | `/api/products?search=sardines` | Search by product name or barcode |
| `GET` | `/api/products?filter=LowStock` | Only items at or below their reorder level |
| `GET` | `/api/products?filter=Expiring` | Only items expired or expiring within 30 days |
| `GET` | `/api/products/{id}` | One product |
| `POST` | `/api/products` | Add a product — returns `201 Created` |
| `PUT` | `/api/products/{id}` | Replace a product's details — returns `204 No Content` |
| `DELETE` | `/api/products/{id}` | Remove a product — returns `204 No Content` |

Errors come back as standard problem details JSON: `400` with a message per field when
validation fails, `404` when the id does not exist, and `409` when a barcode is already used
by another product.

`Grocery.Api/Grocery.Api.http` holds ready-made sample requests you can run from Visual Studio
or the VS Code REST Client extension.

> **Note:** the API has no login and no authentication. Anyone who can reach the port can read
> and change the inventory. That is fine while it runs on your own machine for this activity,
> but it would need authentication before being put on a real server.

---

## How the code is organised

```
Grocery.Api/
  Domain/
    Product.cs                  the product itself: its fields and its rules
  Data/
    AppDbContext.cs             the database session (one DbSet per table)
    Configurations/             column sizes, precision, the unique barcode index
    Migrations/                 EF Core's generated schema history
  Features/Products/
    ProductsController.cs       the five endpoints
    ProductRequest.cs           what the client may send, plus validation rules
    ProductResponse.cs          what the API sends back
    StockFilter.cs              All / LowStock / Expiring
  Shared/
    GlobalExceptionHandler.cs   turns unhandled errors into clean JSON
  Program.cs                    wiring: database, CORS, Swagger

Grocery.Client/src/app/
  core/interceptors/            turns failed HTTP calls into readable messages
  shared/form-error.ts          the red text under an invalid field
  features/products/
    product.model.ts            the TypeScript shape of a product
    product.service.ts          the only file that knows the API URLs
    products-page.*             the page: state, table, search, filters
    product-form.*              the add/edit form and its validation
```

Two ideas worth knowing if you are reading the code:

1. **The entity guards itself.** You cannot build an invalid `Product` — `Product.Create(...)`
   and `product.Update(...)` trim the text and reject blank names or negative numbers, so the
   controller never assigns fields one by one.
2. **The API has its own shapes.** `ProductRequest` and `ProductResponse` are the contract with
   the client, which means the database entity is never sent over the wire.

---

## Troubleshooting

**`28P01: password authentication failed for user "postgres"`**
The password in `Grocery.Api/appsettings.Development.json` does not match your PostgreSQL
installation. Fix it in step 3. If you forgot it, the simplest fix is to reinstall PostgreSQL
and set a password you will remember.

**`Failed to connect to 127.0.0.1:5432` or `No connection could be made`**
PostgreSQL is not running. Open the Windows Services app (`services.msc`), find
`postgresql-x64-…`, and start it.

**`Address already in use` when starting the API**
Something else is on port 5199, usually an older `dotnet run` that never stopped. Close the
other terminal, or change the port in `Grocery.Api/Properties/launchSettings.json` — and if
you do change it, update `Grocery.Client/proxy.conf.json` to the same port.

**The page says "Cannot reach the API. Check that the backend is running."**
Terminal 1 is not running, or it is running on a different port than
`Grocery.Client/proxy.conf.json` expects (`5199` by default).

**Port 4200 is already in use**
Run the client on another port: `npm start -- --port 4300`.

**`npm install` fails or the client will not start**
Check `node -v` is 22.22.3 or newer. If it still fails, delete the `Grocery.Client/node_modules`
folder and run `npm install` again.

**`start.bat` opens and closes straight away**
Run it from a terminal instead so the message stays visible:
`powershell -ExecutionPolicy Bypass -File setup.ps1`

**`start.bat` says a port is being used by another program**
Something unrelated is on that port. Close it, or for the web app pick another port with
`.\start.bat -ClientPort 4300`. The script refuses to continue rather than show you the wrong
app.

**`'dotnet' is not recognized`**
The .NET SDK is not installed, or the terminal was open before you installed it. Close the
terminal, open a new one, and try again.

**You want to reset the data and start over**
Drop the database and let the API recreate it on the next start. In pgAdmin, right-click the
`grocerycrud` database and choose *Delete/Drop*.

**You would rather create the schema manually instead of on startup**
Install the EF Core tool once with `dotnet tool install --global dotnet-ef`, then run:

```bash
dotnet ef database update --project Grocery.Api
```

---

## Checking that everything still compiles

```bash
dotnet build GroceryCrud.sln
cd Grocery.Client
npm run build
```
