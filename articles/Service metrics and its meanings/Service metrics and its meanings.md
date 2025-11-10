---
title: Service metrics and its meanings
tags: [monitoring, sre, observability]
published: true
cover_image: https://perfectmeasuringtape.com/app/uploads/2018/06/Fractional_inches-3.jpg
# devto_id: will be set automatically
---

## Service metrics and its meanings

Whenever you have a system, it doesn't really matters what it does, it is of good measure to… well… measure it.

The purposes are multiple, make sure that it is performing well, measure its overall cost, measure its latency to costumers, etc. It is a fact that it is quite important to do so, but then the following question arises: how?

Well, the answer to that question is not easy, as there are aspects of each service/case/app that are to be considered.

A good example of that is Google itself, and I'm not saying that because they have THE book for [Site Reliability Engineering](https://sre.google/books/), I am talking about relations between the metrics and their inherent meaning on a myriad of services so big that it covers the entire world. On those books they cover a great deal of trial and error on how to measure production systems and how to focus on what is important. See also the companion [SRE Workbook](https://sre.google/books/workbook/) and background on [postmortem culture](https://sre.google/sre-book/postmortem-culture/).

Albeit to that, you might find that those examples are irrelevant for your use case and you'll have to figure everything out for yourself. And that is OK. But one thing is undeniable, those concepts help a bit when they fall on a use case that fits.

From my point of view, there are two basic types of metrics that you can apply those concepts to. They are inherently interconnected, in the sense that one does not exist without the other. Related framing: product "North Star" metrics (see [Amplitude guide](https://amplitude.com/blog/product-north-star-metric)) versus engineering reliability KPIs (e.g. [Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/#the-four-golden-signals)).

## Business meaning

When we talk about metrics from a business standpoint we are trying to quantify whether the service is succeeding in creating (and keeping) value. A metric is a proxy for an outcome; no proxy is perfect, but good ones are:

1. Connected to customer impact (they move when users are happier or churn when they are not)
2. Hard to game (improving the number tends to improve the underlying reality)
3. Stable enough to trend yet responsive enough to detect meaningful change

### Leading vs. lagging indicators

Lagging indicators describe results you usually discover too late (monthly revenue, quarterly churn). Leading indicators move earlier and let you correct course (signup conversion, time-to-value, task success rate). A healthy metric set pairs each critical lagging metric to at least one leading metric that you can act upon. For a primer, see [Leading vs. Lagging Indicators](https://www.bmc.com/blogs/leading-vs-lagging-indicators/).

| Outcome (Lagging) | Example Leading Metrics | Intervention Window |
|-------------------|-------------------------|---------------------|
| Customer retention | Onboarding completion %, First action latency | Days/weeks |
| Revenue growth     | Trial -> paid conversion, Expansion feature adoption | Weeks |
| NPS / Satisfaction ([What is NPS?](https://www.atlassian.com/agile/product-management/nps-score)) | Error-free session %, Page performance (p95) ([Web Vitals](https://web.dev/vitals/)) | Minutes/hours |

### North Star and guardrails

The North Star metric is the clearest expression of sustained value creation (e.g., "weekly active collaborative documents"). Guardrail metrics prevent optimizing the North Star at the expense of health (support tickets backlog, cost per transaction, reliability SLO compliance). If a push increases the North Star but violates a guardrail, you slow down.

### Metric layers

Think in concentric layers:

1. North Star (one, maybe two)
2. Strategic pillars (fairly stable: acquisition, activation, retention, efficiency)
3. Operational KPIs (change more often, tie to teams OKRs)
4. Diagnostic metrics (rich, detailed; used to explain movement, rarely reported upward)

### Business questions to validate

Before adopting a business metric ask: What decision will change if this metric moves? Who owns reacting to it? How fast must we respond? What thresholds define success vs. acceptable vs. alert?

### Common business metric mistakes

- Measuring everything and prioritizing nothing
- Declaring a vanity metric (raw signups) as success without a quality filter
- Lacking a clear owner; metrics without owners decay
- Setting targets without historical baselines or variance analysis
- Not revisiting metrics when the product stage changes (growth vs. efficiency phase)

### Translating to technical metrics

Each business metric should map (not 1:1, but traceably) to technical signals. If "time-to-value" matters, you must instrument latency of first key workflow and session error rates. This translation is the handshake between product and engineering.

## Technical meaning

On the technical side, metrics become the nervous system of operating the service. Their meaning comes from how precisely they reflect user-visible behavior and how actionable they are for engineers.

### Observability pillars vs. service metrics

Observability often cites three pillars: metrics (numeric aggregations), logs (discrete events with context), traces (distributed request flows). Service metrics sit at the top as *interpreted* numbers distilled from raw telemetry. You rarely alert on raw logs; you derive counters, rates, percentiles. See [OpenTelemetry](https://opentelemetry.io/) for standardized telemetry and this discussion on [Monitoring vs. Observability](https://aws.amazon.com/compare/the-difference-between-monitoring-and-observability/).

### Golden signals

Borrowing from SRE practice, the four golden signals of a user-facing system:

1. Latency – How long it takes to serve a request (track both success and error paths, p50/p95/p99).
2. Traffic – Demand size: requests/second, concurrent sessions.
3. Errors – Failure rate: explicit errors, timeouts, correctness failures.
4. Saturation – Resource exhaustion proximity: CPU, memory, queue length.
Add a fifth in many modern systems: Cost – Unit economics per request/job.

### SLIs, SLOs, SLAs

- SLI (Service Level Indicator): Precisely defined measurement of user experience (e.g., "fraction of read API requests completed under 300 ms and returning 2xx").
- SLO (Service Level Objective): Target for SLI over a window ("99.9% weekly").
- SLA (Service Level Agreement): Contractual externally visible commitment; breaching may have penalties. Always set SLO tighter than SLA.

Error Budget = 1 - SLO. It is the allowed unreliability used for change velocity (deploys, experiments). If you burn budget too fast: slow releases, add reliability work. If you never spend budget: you may be over-investing. For alerting strategy, consider [multi-window, multi-burn rate SLO alerts](https://sre.google/workbook/alerting-on-slos/).

### Metric types (Prometheus style)

- Counter: Monotonic increase (e.g., total requests). Alert on *rate* not raw value. ([Prometheus counter](https://prometheus.io/docs/concepts/metric_types/#counter))
- Gauge: Arbitrary up/down (e.g., memory usage, queue depth). ([Prometheus gauge](https://prometheus.io/docs/concepts/metric_types/#gauge))
- Histogram: Buckets of observations (latency). Enables percentiles & tail analysis. ([Prometheus histogram](https://prometheus.io/docs/concepts/metric_types/#histogram))
- Summary: Client-side calculated quantiles; use sparingly due to aggregation limits. ([Prometheus summary](https://prometheus.io/docs/concepts/metric_types/#summary))
Prefer histograms for latency & size; counters for events; gauges for states. Ensure unit consistency (seconds, bytes). Document each metric: name, type, unit, cardinality dimensions. Good primers: [Prometheus histograms and summaries](https://prometheus.io/docs/practices/histograms/) and [Gil Tene on latency percentiles](https://www.youtube.com/watch?v=lJ8ydIuPFeU).

### Cardinality discipline

High-cardinality labels (user_id, session_id) explode storage and slow queries. Guidelines:

- Reserve high cardinality for traces/logs, not primary metrics. ([Prometheus best practices](https://prometheus.io/docs/practices/naming/))
- Dimension by stable groupings (region, API endpoint, plan tier). ([Grafana labels guide](https://grafana.com/docs/grafana/latest/alerting/fundamentals/alert-rules/annotation-label/))
- Keep total series per metric under sane thresholds (e.g., < 10k) unless justified. ([Cardinality explained](https://www.honeycomb.io/blog/cardinality-explained/))

### Instrumentation checklist

1. Define SLIs first (user perspective) then choose raw signals.
2. Standard naming: service_namespace_subsystem_metric_unit (e.g., checkout_api_request_latency_seconds). See [Prometheus naming best practices](https://prometheus.io/docs/practices/naming/).
3. Include outcome labels: status="success|error|timeout".
4. Separate pathologically slow from normal via buckets (e.g., 50,100,200,300,500,800,1200,2000 ms).
5. Emit from a well-tested middleware layer to ensure coverage.

### Aggregation & rollups

Store both raw series and periodic rollups (1m, 5m, 1h) to enable long-range trends affordably. Tail metrics (p99) need raw-ish resolution; cost/traffic can tolerate coarser granularity. See [Recording rules](https://prometheus.io/docs/practices/rules/) and [continuous aggregates](https://medium.com/timescale/real-time-analytics-for-time-series-a-devs-intro-to-continuous-aggregates-b9c38b5746f0/).

### Dashboards vs. alerts

Dashboards are for exploration & storytelling; alerts for actionable interruption. An alert should meet: clear owner, severity classification, runbook link, deduplication logic, and auto-silence conditions (maintenance windows, downstream known incidents). Too many unactionable alerts create alert fatigue; measure mean time to acknowledge (MTTA) and percent of alerts yielding tickets. See [PagerDuty on alert fatigue](https://www.pagerduty.com/resources/digital-operations/learn/alert-fatigue/).

### Dependency metrics

Track upstream SLIs you depend on (e.g., database p99 latency). Decompose incidents faster by correlating service SLI dip with dependency saturation metrics.

### Continuous improvement loop

1. Observe SLI trends and error budget consumption.
2. Perform weekly reliability review: anomalies, top regression sources.
3. Propose experiments (cache change, index) with expected movement.
4. Deploy and compare before/after via change-focused dashboards.
5. Feed learnings into next quarter's reliability & efficiency OKRs.

## Bridging business and technical metrics

The most powerful metrics tell a dual story: "p95 checkout latency improved 20%, and conversion rose 3%". Maintain a mapping document linking each business KPI to:

- Primary SLI(s)
- Key technical driver metrics (cache hit rate, DB lock wait)
- Leading indicator hypotheses (client render time)
Revisit mapping quarterly; prune metrics that no longer explain variance.

## Metric taxonomy cheat sheet

| Layer | Example | Owner | Cadence |
|-------|---------|-------|---------|
| North Star | Weekly active collaborative docs | Product leadership | Weekly |
| SLI | Successful doc save latency p95 < 400ms | SRE/Engineering | Continuous |
| SLO | 99.95% saves < 400ms weekly | SRE | Weekly review |
| Guardrail | Infra cost per save < $0.001 | Finance/Eng | Monthly |
| Diagnostic | DB write lock wait time | Eng team | Ad hoc |

## Common anti-patterns

- Alerting on averages (hide tail pain) instead of percentiles. See [ACM Queue on percentiles](https://queue.acm.org/detail.cfm?id=1814327).
- Chasing "100%" reliability (diminishing returns) vs. defined SLO + error budget. See [Error Budgets](https://sre.google/sre-book/service-level-objectives/#error-budgets).
- Overloading a single metric with too many labels causing cardinality blow-up. See [Prometheus instrumentation pitfalls](https://prometheus.io/docs/practices/instrumentation/#avoid-missing-labels).
- Building dashboards no one uses: track dashboard views, retire stale boards. See [Grafana dashboard tips](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/).
- Confusing throughput with performance (more requests could mean retries from errors). Contrast [RED method](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/) vs. [USE method](https://www.brendangregg.com/usemethod.html).

## Practical example (API service)

Scenario: Public REST API for document editing.
Defined SLIs:

1. Read latency: fraction of GET /doc/{id} served < 250ms.
2. Write success: fraction of PUT /doc/{id} returning 2xx.
3. Editing session stability: sessions without disconnect > 5 minutes.
SLOs: 99.9%, 99.95%, 99% respectively (weekly). Error budget alarms at 50%, 75%, 100% consumption. Business KPI mapped: active editing minutes per user. Hypothesis: Improving read latency p95 will raise active minutes by reducing initial load friction. Run experiment: introduce edge caching; monitor cache hit rate (target > 80%), origin latency drop (expect -30%). Outcome metrics decide rollout.

## Getting started checklist

1. List top 3 user journeys; define one SLI each.
2. Set initial SLOs using historical 4-week median performance minus a modest stretch.
3. Instrument counters for requests, errors; histograms for latency.
4. Create one "golden dashboard" with SLIs + dependency saturation metrics.
5. Define 3 alerts only: SLI burn rate high (short & long window), dependency slowdown, error spike.
6. Write runbooks before enabling alerts.
7. Review after 2 weeks: adjust buckets, remove noisy labels, refine SLO.

## Conclusion

Metrics are a language; alignment happens when business and engineering speak a shared dialect rooted in user experience. Start small, be explicit, iterate continuously. The goal is not more graphs; it's faster, better decisions.
