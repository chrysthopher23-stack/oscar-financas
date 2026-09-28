# Build with CMC — implementation and live-call evidence

## What the app uses

Oscar Finanças uses CoinMarketCap data in the Investments screen to show quotes
for crypto assets held in a user's portfolio, search the asset catalog, and
display recent price history.

- `GET /v3/cryptocurrency/quotes/latest` — batched quote lookup. A live check
  below requested Bitcoin, Ethereum, and Tether together in one upstream call.
- `GET /v3/cryptocurrency/quotes/historical` — grouped seven-day quote history
  for portfolio charts. Implemented; its real upstream response was not part of
  the live check recorded here.
- `GET /v1/cryptocurrency/map` — cached active-asset catalog used for search.
  Implemented; its real upstream response was not part of the live check
  recorded here.

The Flutter client calls the same-origin `/api/crypto/quotes` and
`/api/crypto/search` routes. The Node proxy keeps the CMC credential on the
server, batches selected IDs, caches successful quotes for six hours, and
applies a retry cooldown after provider failures.

## Live response sample

Captured at **2026-09-28 00:22 UTC** through
`createCoinMarketCapService.quotes(['1', '1027', '825'], includeHistory: false)`.
The CMC key was read from the local ignored secret file and was not printed or
included in this repository. The proxy recorded **one upstream quote call** and
returned all three assets:

```json
{
  "upstreamCalls": 1,
  "data": [
    { "id": "1", "priceUsd": "84780.86678995425", "observedAt": "2026-09-28T00:20:59.000Z" },
    { "id": "1027", "priceUsd": "2693.1447877109863", "observedAt": "2026-09-28T00:20:59.000Z" },
    { "id": "825", "priceUsd": "0.9997399431597377", "observedAt": "2026-09-28T00:20:59.000Z" }
  ]
}
```

This sample is a dated snapshot, not a current-price guarantee. The quote
integration accepted the provider response and returned the requested IDs in a
single batched call.

## What CMC makes possible and current limitation

CMC supplies the crypto quote, searchable asset identity, and price-history
data that let a person compare their own recorded holdings in the app. The
integration is read-only: it does not execute trades or provide personalized
investment advice. API quotas and provider availability constrain refreshes;
the app batches IDs and serves cached or stale data where available. The
historical and catalog endpoints are implemented, but need separate live
response evidence before claiming those two calls were independently verified
for the submission.
