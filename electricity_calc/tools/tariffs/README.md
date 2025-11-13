just put this file path,run the converter and run these three things
cd C:\fluttertwee\flutter\electricity_calc
# run your converter here (e.g. .\electricity_calc\tools\tarifs\convert.ps1)
git add docs\tariffs.json
git commit -m "Refresh tariff JSON"
git push origin main



How to publish tariffs from Excel (Option A: Hosted JSON)

This guide assumes your Excel lives at:
  electricity_calc_extra/Tarif_prices.xlsx

What you will do once per year:
1) Edit the Excel with the new year’s rates.
2) Run the converter to generate docs/tariffs.json.
3) Commit/push docs/tariffs.json to GitHub.
4) Enable GitHub Pages (serving the /docs folder).
5) In the app, tap “Check tariff updates now” (or wait for the monthly check).

Excel format (one row per tier)
- Columns: regionKey, displayName, startDate, endDate, tierFrom, tierTo, rate
- Dates: use yyyy-mm-dd (startDate is 1 July; endDate is 30 June of next year or blank for ongoing)
- Last tier per year: leave tierTo blank (open-ended)

Install prerequisites (Windows)
1) Install Python from https://www.python.org/downloads/ (tick “Add Python to PATH”)
2) Open PowerShell in repo root and run:
   py -m pip install --upgrade pip
   py -m pip install pandas openpyxl

Generate tariffs.json (two ways)
- Quick way (uses default paths):
  tools/tariffs/convert.bat

- Manual way (custom paths):
  py tools/tariffs/convert.py electricity_calc_extra/Tarif_prices.xlsx docs/tariffs.json

Publish via GitHub Pages
1) Commit docs/tariffs.json and push to GitHub.
2) In your GitHub repo: Settings → Pages → Set “Deploy from a branch”, folder = /docs.
3) Copy the URL that GitHub shows. Your file will be at:
   https://damic3.github.io/electricity_calc/tariffs.json

Point the app to the URL
- In lib/main.dart, set TariffManager.tariffsUrl to the URL above.
- In the app Settings, tap “Check tariff updates now”.

That’s it. Next year, repeat: update Excel → run converter → commit docs/tariffs.json.

