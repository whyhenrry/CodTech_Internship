#!/bin/bash
# Step 1: Export MySQL
mysqldump -u root -p mydb > mydb_mysql.sql

# Step 2: Transform dump
python transform.py mydb_mysql.sql mydb_pg.sql

# Step 3: Import into PostgreSQL
psql -U postgres -d mydb -f mydb_pg.sql

# Step 4: Verify counts
psql -U postgres -d mydb -c "SELECT COUNT(*) FROM student;"