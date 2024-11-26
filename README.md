# Smart Budget Tracker - PL/SQL Project

Welcome to the Smart Budget Tracker, a purely PL/SQL-based application designed to simplify expense tracking, debt management, and financial analysis for individuals and groups. This project focuses on seamless management and insightful reporting, helping users achieve better financial control.

**Features**
1. Expense Management
Add_Expense:
Add a new expense for a user in a specific group. Key details include:

Amount
Category (e.g., Food, Travel, Entertainment)
Description (optional)
Expense date (defaults to the current date if not provided).

Edit_Expense:
Update an existing expense by modifying:

Amount
Category
Description
Delete_Expense:
Safely remove an expense, with error handling for:

Non-existent expense records
Insufficient user permissions
View_Expenses_By_Group:
Display all expenses within a specified group, categorized by members, amounts, and categories for detailed tracking.

View_Expenses_By_User:
List all expenses added by a specific user, helping with personal budgeting and analysis.




**2. Expense Splitting Functionality**
Split_Expense_Equally:
Automatically divide the total expense equally among all group members, updating each member's balance.

Split_Expense_Custom:
Allocate custom percentages or amounts to each group member for flexible expense sharing.

Calculate_Total_Owed:
Calculate and display the total amount a user owes or is owed by other group members, using aggregate functions for accuracy.



**3. Reporting and Summaries**
Generate_User_Report:
Summarizes a user's financial activities, including:

Total expenses
Amount owed to others
Amount others owe the user
Generate_Group_Report:
Provides a detailed group summary, showing:

Total group expenses
Breakdown by category
Contributions by individual members
View_Balance_Sheet:
Generates a balance sheet for a group, showing:

Individual balances
Amounts owed or due between members




**4. Advanced Reporting**
User_Monthly_Spending_Report:
Offers a breakdown of a user's spending for a selected month, displaying:

Total spending
Category-wise distribution

User_Debt_Report:

Provides a detailed summary of a user’s debts, highlighting:

Total amount owed to others
Total amount others owe the user
Individual debt balances with group members


Category_Wise_Spending:

Analyzes spending by category, showing:

Total expenses per category
Percentage distribution for better budget planning

Group_Wise_Spending:

Summarizes group spending, displaying:

Total expenses for the group
Contributions by each member
Category-wise distribution


Saving_Recommendation:

Suggests actionable savings tips based on spending trends, such as:

Categories where spending can be reduced
Income percentage allocation for savings
Customized financial tips for better planning









**Benefits**


*Effortless Tracking: Manage personal and group finances with ease.

*Insightful Reporting: Gain deep insights into spending habits and debt status with advanced reports.

*Fair Expense Sharing: Ensure equitable contributions with equal and custom expense-sharing options.

*Smart Recommendations: Receive actionable saving tips tailored to your spending patterns.

*Secure and Reliable: Robust error handling and permission management ensure data integrity and user privacy.

**Usage**

**Pre-Requisites**

Oracle Database with PL/SQL support.
Properly initialized tables for Users, Groups, Expenses, Group_Members, and Debts.
Setup
Use the provided scripts to create and populate tables.
Initialize data using procedures like Add_New_User and Add_Group.
Execution
Utilize the provided procedures and functions to manage expenses and generate insightful reports.

**Conclusion**

The Smart Budget Tracker empowers you to manage expenses, track debts, and achieve financial goals efficiently. Its comprehensive features and smart reporting ensure a seamless budgeting experience for individuals and groups alike. Start your journey to better financial management today!

