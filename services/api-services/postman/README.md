This folder contains Postman collection and performance script to test the AgroAPI services.

Quick run (after installing deps):

- Install dev dependencies:
  npm install

- Functional tests (Newman):
  npm run test:functional

- Performance test (Artillery):
  npm run test:perf

- Run both sequentially:
  npm run test:all

Notes:
- The Newman report HTML will be output to ./postman/reports/newman-report.html
- Artillery JSON report will be at ./postman/reports/artillery-report.json
- You can override the base URL and credentials by editing postman/AgroAPI-environment.json or setting environment variables before running npm scripts.
