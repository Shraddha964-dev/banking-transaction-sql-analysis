# 🏦 Banking Transaction SQL Analysis

End-to-end SQL analysis of retail banking transactions to uncover customer 
spending patterns, detect anomalies, and segment customers by behavior.

## 📊 Business Problem

Banks generate millions of transactions daily but struggle to turn raw 
transaction data into actionable insights. This project answers 5 key 
business questions using only SQL:

- Who are the highest-value customers and how do they behave?
- Which spending categories and channels drive the most volume?
- Are there suspicious transactions that indicate fraud?
- How can we segment customers for targeted marketing?
- Which customer cohorts retain best over time?

## 🔍 Analysis Sections

| Section | Description | Key SQL Concepts Used |
|---|---|---|
| 1. EDA | Transaction volume, category & channel breakdown | GROUP BY, aggregations |
| 2. Customer Behavior | Top spenders, MoM growth | Window functions, LAG() |
| 3. Activity Streaks | Consecutive active months per customer | ROW_NUMBER(), self-join logic |
| 4. Anomaly Detection | Statistical outlier flagging (Z-score > 3) | STDDEV(), CTEs, Z-score |
| 5. Fraud Patterns | Rapid repeat transactions < 10 minutes | LAG(), EXTRACT, EPOCH |
| 6. Decline Rate | Customers with >30% transaction decline rate | FILTER, HAVING |
| 7. RFM Segmentation | Champions, Loyal, At-Risk, Lost segments | NTILE(), CASE, CTEs |
| 8. Cohort Retention | Monthly retention % per customer cohort | DATE_TRUNC(), AGE(), multi-CTE |

## 💡 Key Findings (from synthetic dataset)

- **Champion customers** (top RFM score) represent ~15% of base but 
  contribute 60%+ of total revenue
- **Fraud signals** detected in 2.3% of transactions via Z-score 
  outlier method and rapid transaction pattern analysis
- **Mobile channel** drives highest transaction volume; Branch has 
  highest average transaction value
- **Month 1 → Month 2 retention** drops ~35% across cohorts — 
  indicating strong need for early onboarding engagement

## 🛠️ Tech Stack

- **Language:** SQL (PostgreSQL syntax, compatible with SQLite)
- **Concepts:** CTEs, Window Functions, Subqueries, NTILE, LAG/LEAD,
  DATE_TRUNC, FILTER, STDDEV, Cohort Analysis, RFM Scoring

## 📁 File Structure
```
banking-transaction-sql-analysis/
├── banking_transactions_analysis.sql   # All 11 queries with comments
└── README.md
```

## 🚀 How to Run

1. Set up a PostgreSQL or SQLite database
2. Create tables using the schema in Section 1 of the .sql file
3. Load your transaction data (or generate synthetic data)
4. Run queries section by section in any SQL client 
   (DBeaver, pgAdmin, DB Browser for SQLite)

## 🔗 Related Projects

- [E-Commerce Customer Segmentation](https://github.com/Shraddha964-dev/ecommerce-customer-analysis) 
  — Same RFM segmentation logic implemented in Python + Scikit-learn


## 👩‍💻 About ME

I am actively seeking entry-level opportunities in Data Analyst and continuously building projects to strengthen my skills.

If you have suggestions or feedback, feel free to share.

If you find this helpful, feel free to star the repository!

If you liked what you saw, want to have a chat with me about the portfolio, work opportunities, or collaboration, shoot an email at ssajane86@gmail.com.

[LinkedIn](https://www.linkedin.com/in/shraddha-sajane) | 
[GitHub](https://github.com/Shraddha964-dev)
