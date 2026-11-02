CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        bank_name TEXT,
        account_number TEXT,
        balance INTEGER NOT NULL DEFAULT 0,
        include_in_total INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        card_company TEXT,
        billing_day INTEGER,
        account_id INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      );
CREATE TABLE budget_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        month_start_day INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(start_date, end_date)
      );
CREATE TABLE monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(period_id, category_id),
        FOREIGN KEY (period_id) REFERENCES budget_periods(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER,
        payment_method_id INTEGER,
        account_id INTEGER NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        refunded_expense_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
        FOREIGN KEY (account_id) REFERENCES accounts(id),
        FOREIGN KEY (refunded_expense_id) REFERENCES transactions(id)
      );
CREATE TABLE account_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        source_type TEXT NOT NULL,
        source_id INTEGER,
        delta INTEGER NOT NULL,
        balance_after INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      );
CREATE TABLE expense_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        payment_method_id INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
      );
CREATE TABLE alert_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        threshold INTEGER NOT NULL,
        sent_at TEXT NOT NULL,
        UNIQUE(period_id, category_id, threshold),
        FOREIGN KEY (period_id) REFERENCES budget_periods(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      );
