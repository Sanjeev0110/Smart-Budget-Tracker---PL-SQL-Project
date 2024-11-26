--  Users table

CREATE TABLE Users (
    User_ID NUMBER PRIMARY KEY,
    User_Name VARCHAR2(100) NOT NULL,
    Phone_Number VARCHAR2(10) UNIQUE NOT NULL,
    Email VARCHAR2(100) UNIQUE NOT NULL,
    CONSTRAINT chk_phone_number CHECK (REGEXP_LIKE(Phone_Number, '^\d{10}$')),
    CONSTRAINT chk_email_format CHECK (REGEXP_LIKE(Email, '^[A-Za-z0-9._]+@[A-Za-z0-9.-]+.[A-Za-z]{2,}$'))
);



--  Groups table
CREATE TABLE Groups (
    Group_ID NUMBER PRIMARY KEY,
    Group_Name VARCHAR2(100) NOT NULL
);


ALTER TABLE Groups
ADD CONSTRAINT group_name_unique UNIQUE (Group_Name);


--  Group_Members table
CREATE TABLE Group_Members (
    Group_ID NUMBER NOT NULL,
    User_ID NUMBER NOT NULL,
    CONSTRAINT fk_group_members_group FOREIGN KEY (Group_ID) REFERENCES Groups(Group_ID),
    CONSTRAINT fk_group_members_user FOREIGN KEY (User_ID) REFERENCES Users(User_ID)
);


-- Expenses table
CREATE TABLE Expenses (
    Expense_ID NUMBER PRIMARY KEY,
    User_ID NUMBER NOT NULL,
    Group_ID NUMBER NOT NULL,
    Amount NUMBER(10,2) NOT NULL,
    Category VARCHAR2(50) NOT NULL,
    Description VARCHAR2(255),
    Expense_Date DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_expenses_user FOREIGN KEY (User_ID) REFERENCES Users(User_ID),
    CONSTRAINT fk_expenses_group FOREIGN KEY (Group_ID) REFERENCES Groups(Group_ID)
);




--  Debts table
CREATE TABLE Debts (
    Debt_ID NUMBER PRIMARY KEY,
    From_User_ID NUMBER NOT NULL,
    To_User_ID NUMBER NOT NULL,
    Amount NUMBER(10,2) NOT NULL,
    Settled CHAR(1) DEFAULT 'N' NOT NULL,
    Settlement_Date DATE,
    CONSTRAINT fk_debts_from_user FOREIGN KEY (From_User_ID) REFERENCES Users(User_ID),
    CONSTRAINT fk_debts_to_user FOREIGN KEY (To_User_ID) REFERENCES Users(User_ID),
    CONSTRAINT chk_settled CHECK (Settled IN ('Y', 'N'))
);

ALTER TABLE Debts ADD Expense_ID NUMBER;









create or replace PROCEDURE Add_New_User (
    p_user_name IN VARCHAR2,
    p_phone_number IN VARCHAR2,
    p_email IN VARCHAR2
) IS
    v_count NUMBER;
    v_user_id NUMBER; 
    v_email_lower VARCHAR2(100); -- Variable to hold the lowercase email
BEGIN
    -- Convert the email to lowercase for case-insensitive comparison
    v_email_lower := LOWER(p_email);

    -- Check if phone number is valid
    IF NOT REGEXP_LIKE(p_phone_number, '^\d{10}$') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid phone number format. It should be exactly 10 digits without alphabets.');
    END IF;

    -- Check if email is valid
    IF NOT REGEXP_LIKE(v_email_lower, '^[A-Za-z0-9._]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}([.][A-Za-z]{2,})?$') THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid email format. Please provide a valid email address.');
    END IF;

    -- Check if phone number already exists
    SELECT COUNT(*)
    INTO v_count
    FROM Users
    WHERE Phone_Number = p_phone_number;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Phone number ' || p_phone_number || ' already exists. Please use a different phone number.');
    END IF;

    -- Check if email already exists (using the lowercased email)
    SELECT COUNT(*)
    INTO v_count
    FROM Users
    WHERE LOWER(Email) = v_email_lower;

    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Email ' || p_email || ' already exists. Please use a different email address.');
    END IF;

    -- Insert the new user into the Users table
    INSERT INTO Users (User_Name, Phone_Number, Email)
    VALUES (p_user_name, p_phone_number, v_email_lower) 
    RETURNING User_ID INTO v_user_id; 

   
    DBMS_OUTPUT.PUT_LINE('User ID ' || v_user_id || ' ' || p_user_name || ' added successfully.');

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20006, 'Error: Duplicate value found while adding user. Please check your inputs.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Error occurred while adding user: ' || SQLERRM);
END Add_New_User;









create or replace PROCEDURE Remove_User (
    p_user_id IN NUMBER
) IS
    v_count NUMBER;
    v_unsettled_debt_count NUMBER;
    v_user_name VARCHAR2(100);  -- Variable to hold the user's name
BEGIN
    -- Check if the User exists
    SELECT COUNT(*)
    INTO v_count
    FROM Users
    WHERE User_ID = p_user_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'User with ID ' || p_user_id || ' does not exist. Unable to proceed with removal.');
    END IF;
  
    -- Fetch the user's name
    SELECT User_Name INTO v_user_name
    FROM Users
    WHERE User_ID = p_user_id;

    -- Check if the user has any unsettled debts
    SELECT COUNT(*)
    INTO v_unsettled_debt_count
    FROM Debts
    WHERE (From_User_ID = p_user_id OR To_User_ID = p_user_id)
      AND Settled = 'N';

    IF v_unsettled_debt_count > 0 THEN
        RAISE_APPLICATION_ERROR( -20004, 'User ID ' || p_user_id || ' (' || v_user_name || ') cannot be removed due to ' || v_unsettled_debt_count || 
            ' unsettled debts. Please ensure all debts are settled or transferred to another user before retrying.'  );
    END IF;

    -- Remove user from Group_Members 
    DELETE FROM Group_Members
    WHERE User_ID = p_user_id;

    -- Remove the user from Users table
    DELETE FROM Users
    WHERE User_ID = p_user_id;

 
    DBMS_OUTPUT.PUT_LINE('User with ID ' || p_user_id || ' (' || v_user_name || ') removed successfully.');

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -2292 THEN
           RAISE_APPLICATION_ERROR( -20099,   'User ID ' || p_user_id || ' (' || v_user_name ||  ')
           cannot be removed because there are still related records linked to this user. 
           Please take care of those connections first, then try again.');
           
           ELSE
            RAISE_APPLICATION_ERROR(-20099, 'Error occurred while removing user: ' || SQLERRM);
        END IF;
END Remove_User;






create or replace PROCEDURE Edit_User (
    p_user_id IN NUMBER,                         
    p_user_name IN VARCHAR2 DEFAULT NULL,         
    p_phone_number IN NUMBER DEFAULT NULL,        
    p_email IN VARCHAR2 DEFAULT NULL              
) IS
    v_count NUMBER;                          
BEGIN
    -- Check if the user exists
    SELECT COUNT(*)
    INTO v_count
    FROM Users
    WHERE User_ID = p_user_id;

    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'User with ID ' || p_user_id || ' does not exist. Unable to edit.');
    END IF;

    -- Check if the phone number is provided and valid
    IF p_phone_number IS NOT NULL THEN
        IF NOT REGEXP_LIKE(p_phone_number, '^[0-9]{10}$') THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid phone number format. It should be exactly 10 digits.');
        END IF;

        -- Check if the new phone number is already associated with another user
        SELECT COUNT(*)
        INTO v_count
        FROM Users
        WHERE Phone_Number = p_phone_number AND User_ID != p_user_id;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Phone number ' || p_phone_number || ' is already associated with another user. Please use a different phone number.');
        END IF;
    END IF;

    -- Check if the email is provided and valid
    IF p_email IS NOT NULL THEN
        IF NOT REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
            RAISE_APPLICATION_ERROR(-20002, 'Invalid email format. Please provide a valid email address.');
        END IF;

        -- Check if the new email is already associated with another user
        SELECT COUNT(*)
        INTO v_count
        FROM Users
        WHERE Email = p_email AND User_ID != p_user_id;

        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Email ' || p_email || ' is already associated with another user. Please use a different email address.');
        END IF;
    END IF;

    -- Update the user details only for the fields that are not NULL
    UPDATE Users
    SET 
        User_Name = NVL(p_user_name, User_Name),      -- Only update if new value is provided
        Phone_Number = NVL(p_phone_number, Phone_Number),
        Email = NVL(p_email, Email)
    WHERE User_ID = p_user_id;

    -- Success message
    DBMS_OUTPUT.PUT_LINE('User with ID ' || p_user_id || ' has been successfully updated.');

EXCEPTION
    -- Handle any unexpected errors and display an appropriate message
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Error occurred while updating user: ' || SQLERRM);
END Edit_User;






create or replace PROCEDURE View_Users IS
    v_user_count NUMBER;
    CURSOR user_cursor IS
        SELECT User_ID, User_Name, Phone_Number, Email
        FROM Users
        ORDER BY User_ID;
        
    v_user user_cursor%ROWTYPE;
BEGIN
    -- Get the total count of users
    SELECT COUNT(*) INTO v_user_count FROM Users;

   
    DBMS_OUTPUT.PUT_LINE('Total number of users: ' || v_user_count);
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('| User ID | Name                 | Phone Number | Email                    |');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------');

    -- Open the cursor and display user information
    OPEN user_cursor;
    LOOP
        FETCH user_cursor INTO v_user;
        EXIT WHEN user_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE('| ' || LPAD(v_user.User_ID, 7) || 
                             ' | ' || RPAD(SUBSTR(v_user.User_Name, 1, 20), 20) || 
                             ' | ' || LPAD(v_user.Phone_Number, 12) || 
                             ' | ' || RPAD(SUBSTR(v_user.Email, 1, 28), 28) || ' |');
    END LOOP;
    CLOSE user_cursor;
    
  
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------');
END View_Users;







create or replace PROCEDURE Add_Group ( 
    p_group_name IN VARCHAR2
) IS
    v_group_id NUMBER;
    v_count    NUMBER;
    v_normalized_group_name VARCHAR2(100);
BEGIN
    -- Check if the group name is empty 
    IF TRIM(p_group_name) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: Group name cannot be empty or consist only of spaces.');
    END IF;

    v_normalized_group_name := UPPER(TRIM(REPLACE(p_group_name, ' ', '')));

    SELECT COUNT(*)
    INTO v_count
    FROM Groups
    WHERE UPPER(TRIM(REPLACE(Group_Name, ' ', ''))) = v_normalized_group_name;

    IF v_count > 0 THEN
        -- If duplicate name is found, raise an error with a clear message
        RAISE_APPLICATION_ERROR(-20001, 'Error: A group with the name "' || p_group_name || '" already exists. Please use a different name.');
    END IF;


    SELECT NVL(MAX(Group_ID), 0) + 1
    INTO v_group_id
    FROM Groups;

    -- Insert the new group
    INSERT INTO Groups (Group_ID, Group_Name)
    VALUES (v_group_id, p_group_name);

    -- Success message
    DBMS_OUTPUT.PUT_LINE('Group "' || p_group_name || '" added successfully with ID: ' || v_group_id);

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'An unexpected error occurred: ' || SQLERRM);
END Add_Group;




create or replace PROCEDURE Remove_Group (
    p_group_id IN NUMBER
) IS
    v_group_exists NUMBER;
BEGIN
    -- Check if the group exists
    SELECT COUNT(*)
    INTO v_group_exists
    FROM Groups
    WHERE Group_ID = p_group_id;

    IF v_group_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Group ID ' || p_group_id || ' does not exist. Please verify the ID and provide a valid one.');
    END IF;

    -- Delete the group from the Groups table
    DELETE FROM Groups
    WHERE Group_ID = p_group_id;

    DBMS_OUTPUT.PUT_LINE('Group with ID ' || p_group_id || ' has been successfully removed.');

EXCEPTION
    -- Handle the foreign key violation (ORA-02292)
    WHEN OTHERS THEN
        IF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Unable to delete Group ID ' || p_group_id || ' due to associated dependent records.
                                            Please ensure all related records are removed before retrying.');
        ELSE
            RAISE_APPLICATION_ERROR(-20099, 'An unexpected error occurred while attempting to remove the group: ' || SQLERRM);
        END IF;
END Remove_Group;




create or replace PROCEDURE Edit_Group (
    p_group_id IN NUMBER,
    p_new_group_name IN VARCHAR2
) IS
    v_group_exists NUMBER;
BEGIN
    -- Check if the group exists
    SELECT COUNT(*) INTO v_group_exists
    FROM Groups
    WHERE Group_ID = p_group_id;

    IF v_group_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error: Group ID ' || p_group_id || ' does not exist.');
    END IF;

    -- Update the group name
    UPDATE Groups
    SET Group_Name = p_new_group_name
    WHERE Group_ID = p_group_id;

    DBMS_OUTPUT.PUT_LINE('Group with ID: ' || p_group_id || ' has been updated to "' || p_new_group_name || '".');
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Error occurred while editing group: ' || SQLERRM);
END Edit_Group;






create or replace PROCEDURE View_Groups AS
BEGIN
  
    DBMS_OUTPUT.PUT_LINE('------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('| Group ID |        Group Name           |');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------');
    
    -- Loop through each group and display the details
    FOR group_rec IN (SELECT Group_ID, Group_Name FROM Groups ORDER BY Group_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('| ' || LPAD(group_rec.Group_ID, 8) || ' | ' || RPAD(group_rec.Group_Name, 25) || ' |');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------');
END View_Groups;







create or replace PROCEDURE Add_User_To_Group (
    p_user_id IN NUMBER,
    p_group_id IN NUMBER
) IS
    v_user_exists NUMBER;
    v_group_exists NUMBER;
    v_user_in_group NUMBER;
    v_user_name VARCHAR2(100);  -- Variable to hold the user's name
    v_group_name VARCHAR2(100);  -- Variable to hold the group's name
BEGIN
    -- Check if the user exists
    SELECT COUNT(*) INTO v_user_exists
    FROM Users
    WHERE User_ID = p_user_id;

    IF v_user_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: User ID ' || p_user_id || ' does not exist.');
    END IF;

    -- Check if the group exists
    SELECT COUNT(*) INTO v_group_exists
    FROM Groups
    WHERE Group_ID = p_group_id;

    IF v_group_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error: Group ID ' || p_group_id || ' does not exist.');
    END IF;

    -- Check if the user is already in the group
    SELECT COUNT(*) INTO v_user_in_group
    FROM Group_Members
    WHERE User_ID = p_user_id AND Group_ID = p_group_id;

    IF v_user_in_group > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error: User ID ' || p_user_id || ' is already a member of Group ID ' || p_group_id || '.');
    END IF;

    -- Fetch the user's name
    SELECT User_Name INTO v_user_name
    FROM Users
    WHERE User_ID = p_user_id;

    -- Fetch the group's name
    SELECT Group_Name INTO v_group_name
    FROM Groups
    WHERE Group_ID = p_group_id;

    -- Insert the user into the group
    INSERT INTO Group_Members (Group_ID, User_ID)
    VALUES (p_group_id, p_user_id);

    -- Success message with user and group names
    DBMS_OUTPUT.PUT_LINE('User ID ' || p_user_id || ' (' || v_user_name || ') has been added to Group ID ' || p_group_id || ' (' || v_group_name || ') successfully.');

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Error occurred while adding user to group: ' || SQLERRM);
END Add_User_To_Group;




create or replace PROCEDURE View_Users_In_Groups AS
BEGIN
   
    DBMS_OUTPUT.PUT_LINE('User_ID  | User_Name           | Group_ID  | Group_Name');
    DBMS_OUTPUT.PUT_LINE('--------- | -------------------- | ---------- | -------------');

    FOR rec IN (
        SELECT  u.User_ID, u.User_Name, g.Group_ID, g.Group_Name
        FROM  Users u, Group_Members gm, Groups g
        WHERE u.User_ID = gm.User_ID  AND g.Group_ID = gm.Group_ID
        ORDER BY  u.User_ID, g.Group_ID
    ) LOOP
     
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.User_ID, 8) || ' | ' || 
            RPAD(rec.User_Name, 20) || ' | ' || 
            RPAD(rec.Group_ID, 9) || ' | ' || 
            rec.Group_Name
        );
    END LOOP;
    IF SQL%ROWCOUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No users are currently associated with any groups.');
    END IF;

EXCEPTION

    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No users or groups found. Please ensure the tables are populated.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END View_Users_In_Groups;







create or replace PROCEDURE Get_Group_Members (
    p_group_id IN NUMBER
) IS
    v_user_name VARCHAR2(100);  -- Variable to hold the user's name
    v_group_name VARCHAR2(100);  -- Variable to hold the group's name
    v_member_count NUMBER := 0;  -- Counter for members

BEGIN
    -- Check if the group exists and get the group name
    SELECT Group_Name INTO v_group_name
    FROM Groups
    WHERE Group_ID = p_group_id;

    IF v_group_name IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: Group ID ' || p_group_id || ' does not exist.');
    END IF;

    
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('Members of Group: ' || v_group_name || ' (ID: ' || p_group_id || ')', 45, ' ') || '|');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('User ID', 15, ' ') || '| ' || RPAD('Name', 30, ' ') || '|');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');

    -- Cursor to fetch user IDs belonging to the specified group
    FOR member IN (
        SELECT User_ID
        FROM Group_Members
        WHERE Group_ID = p_group_id
        order by User_ID
    ) LOOP
        -- Fetch the user's name using the User_ID from the cursor
        SELECT User_Name INTO v_user_name
        FROM Users
        WHERE User_ID = member.User_ID;

        DBMS_OUTPUT.PUT_LINE(RPAD(member.User_ID, 15, ' ') || '| ' || RPAD(v_user_name, 30, ' ') || '|');
        v_member_count := v_member_count + 1;  -- Increment the member count
    END LOOP;

    -- If no members found, display a message
    IF v_member_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(RPAD('No members found for Group: ' || v_group_name || ' (ID: ' || p_group_id || ')', 45, ' ') || '|');
    END IF;

    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: No data found for User ID in Group ID ' || p_group_id || '.');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20099, 'Error occurred while fetching group members: ' || SQLERRM);
END Get_Group_Members;








create or replace PROCEDURE Add_Expense (
    p_User_ID IN NUMBER,
    p_Group_ID IN NUMBER,
    p_Amount IN NUMBER,
    p_Category IN VARCHAR2,
    p_Description IN VARCHAR2 DEFAULT NULL,
    p_Expense_Date IN DATE  -- Parameter for the expense date
) AS
    v_User_Exists NUMBER;
    v_Group_Exists NUMBER;
    v_User_Name VARCHAR2(100);     
    v_Group_Name VARCHAR2(100);
    v_User_In_Group NUMBER;
BEGIN
    -- Check if the User_ID exists in the Users table
    SELECT COUNT(*)
    INTO v_User_Exists
    FROM Users
    WHERE User_ID = p_User_ID;

    IF v_User_Exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: User ID ' || p_User_ID || ' does not exist.');
    END IF;

    -- Check if the Group_ID exists in the Groups table
    SELECT COUNT(*)
    INTO v_Group_Exists
    FROM Groups
    WHERE Group_ID = p_Group_ID;

    IF v_Group_Exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error: Group ID ' || p_Group_ID || ' does not exist.');
    END IF;

    -- Retrieve the user's name for confirmation message
    SELECT User_Name 
    INTO v_User_Name
    FROM Users
    WHERE User_ID = p_User_ID;

    -- Retrieve the group's name for confirmation message
    SELECT Group_Name 
    INTO v_Group_Name
    FROM Groups
    WHERE Group_ID = p_Group_ID;

    -- Check if the user is part of the group in Group_Members table
    SELECT COUNT(*)
    INTO v_User_In_Group
    FROM Group_Members
    WHERE User_ID = p_User_ID
    AND Group_ID = p_Group_ID;

    IF v_User_In_Group = 0 THEN
        RAISE_APPLICATION_ERROR(-20007, 'Error: User ID ' || p_User_ID || ' (' || v_User_Name ||  ')  is not a member of Group ID ' || p_Group_ID || ' ("' || v_Group_Name || '").');
    END IF;

    IF p_Amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error: Amount must be greater than zero.');
    END IF;

    -- Check if Category is provided and within length constraints
    IF p_Category IS NULL THEN
        RAISE_APPLICATION_ERROR(-20004, 'Error: Category cannot be NULL.');
    ELSIF LENGTH(p_Category) > 50 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error: Category exceeds the maximum length of 50 characters.');
    END IF;

    -- Validate the Expense_Date
    IF p_Expense_Date IS NULL THEN
        RAISE_APPLICATION_ERROR(-20006, 'Error: Expense Date cannot be NULL.');
    END IF;

    -- Insert the expense if all validations pass
    INSERT INTO Expenses (User_ID, Group_ID, Amount, Category, Description, Expense_Date)
    VALUES (p_User_ID, p_Group_ID, p_Amount, p_Category, p_Description, p_Expense_Date);

    -- Output confirmation message in DD-MM-YYYY format
    DBMS_OUTPUT.PUT_LINE('User ID ' || p_User_ID || ' (' || v_User_Name || 
                         ') successfully added an expense of ' || p_Amount || ' rupees to Group ID ' || 
                         p_Group_ID || ' ("' || v_Group_Name || '") under the category "' || 
                         p_Category || '" on ' || TO_CHAR(p_Expense_Date, 'DD-MM-YYYY') || '.');

END Add_Expense;






create or replace PROCEDURE Edit_Expense (
    p_Expense_ID IN NUMBER,
    p_User_ID IN NUMBER DEFAULT NULL,   
    p_Group_ID IN NUMBER DEFAULT NULL, 
    p_Amount IN NUMBER DEFAULT NULL,    
    p_Category IN VARCHAR2 DEFAULT NULL,
     p_Description IN VARCHAR2 DEFAULT NULL,
    p_Expense_Date IN DATE DEFAULT NULL 
) AS
    v_User_Exists NUMBER;
    v_Group_Exists NUMBER;
    v_Expense_Exists NUMBER;
BEGIN
    -- Check if the Expense_ID exists in the Expenses table
    SELECT COUNT(*)
    INTO v_Expense_Exists
    FROM Expenses
    WHERE Expense_ID = p_Expense_ID;

    IF v_Expense_Exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: The specified Expense ID ' || p_Expense_ID || ' does not exist.');
    END IF;

    -- Check if the User_ID exists, only if a new User_ID is provided
    IF p_User_ID IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_User_Exists
        FROM Users
        WHERE User_ID = p_User_ID;

        IF v_User_Exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Error: The specified User ID ' || p_User_ID || ' does not exist.');
        END IF;
    END IF;

    -- Check if the Group_ID exists, only if a new Group_ID is provided
    IF p_Group_ID IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_Group_Exists
        FROM Groups
        WHERE Group_ID = p_Group_ID;

        IF v_Group_Exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Error: The specified Group ID ' || p_Group_ID || ' does not exist.');
        END IF;
    END IF;

    -- Check if Amount is positive, only if a new Amount is provided
    IF p_Amount IS NOT NULL THEN
        IF p_Amount <= 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Error: The Amount must be greater than zero.');
        END IF;
    END IF;

    -- Validate the Expense_Date, only if a new Expense_Date is provided
    IF p_Expense_Date IS NOT NULL THEN
        IF p_Expense_Date IS NULL THEN
            RAISE_APPLICATION_ERROR(-20005, 'Error: Expense Date cannot be NULL.');
        END IF;
    END IF;

    -- Update the expense record only for the fields that are not NULL
    UPDATE Expenses
    SET 
        User_ID = NVL(p_User_ID, User_ID),          -- Update if new User_ID is provided, else retain old value
        Group_ID = NVL(p_Group_ID, Group_ID),       -- Update if new Group_ID is provided, else retain old value
        Amount = NVL(p_Amount, Amount),             -- Update if new Amount is provided, else retain old value
        Category = NVL(p_Category, Category),       -- Update if new Category is provided, else retain old value
        Description = NVL(p_Description, Description),  
        Expense_Date = NVL(p_Expense_Date, Expense_Date)  -- Update if new Expense_Date is provided, else retain old value
    WHERE Expense_ID = p_Expense_ID;

    -- Output confirmation message
    DBMS_OUTPUT.PUT_LINE('Expense ID ' || p_Expense_ID || ' has been successfully updated.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An error occurred: ' || SQLERRM);
END Edit_Expense;  



create or replace PROCEDURE Remove_Expense (
    p_Expense_ID IN NUMBER
) AS
    v_Expense_Count NUMBER;
BEGIN
    -- Check if the Expense_ID exists in the Expenses table
    SELECT COUNT(*)
    INTO v_Expense_Count
    FROM Expenses
    WHERE Expense_ID = p_Expense_ID;

    IF v_Expense_Count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: The specified Expense ID ' || p_Expense_ID || ' does not exist.');
    END IF;

    -- Delete the expense if it exists
    DELETE FROM Expenses
    WHERE Expense_ID = p_Expense_ID;

    DBMS_OUTPUT.PUT_LINE('Expense ID ' || p_Expense_ID || ' has been removed successfully.');
END Remove_Expense; 




create or replace PROCEDURE View_Expenses AS
BEGIN
    -- Output table header
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Expense ID | User ID |     User Name       | Group ID |        Group Name       |     Amount     |      Category       |          Description          |    Date                  ');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------');

    -- Retrieve and display expenses for all users and groups
    FOR rec IN (
        SELECT e.Expense_ID, e.User_ID, u.User_Name, e.Group_ID, g.Group_Name, e.Amount, 
               e.Category, NVL(e.Description, 'N/A') AS Description, TO_CHAR(e.Expense_Date, 'YYYY-MM-DD') AS Expense_Date
        FROM Expenses e
        JOIN Users u ON e.User_ID = u.User_ID
        JOIN Groups g ON e.Group_ID = g.Group_ID
        ORDER BY e.Expense_ID, e.Group_ID, e.Expense_Date DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            LPAD(rec.Expense_ID, 12) || ' | ' ||
            LPAD(rec.User_ID, 8) || ' | ' ||
            RPAD(rec.User_Name, 18) || ' | ' ||  
            LPAD(rec.Group_ID, 7) || ' | ' ||
            RPAD(rec.Group_Name, 23) || ' | ' ||  
            RPAD(TO_CHAR(rec.Amount, '9999999.99'), 14) || ' | ' ||  
            RPAD(rec.Category, 20) || ' | ' ||
            RPAD(rec.Description, 30) || ' | ' ||  
            rec.Expense_Date
        );
    END LOOP;

    -- Display total count of expenses added
    DECLARE
        v_Total_Expenses NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_Total_Expenses
        FROM Expenses;

        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total Expenses Recorded: ' || v_Total_Expenses);
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------');
    END;

END View_Expenses;





create or replace PROCEDURE View_Expenses_By_User(p_User_ID IN NUMBER DEFAULT NULL) IS
    v_User_Name VARCHAR2(40);
    v_Total_Expenses NUMBER := 0;
BEGIN

    IF p_User_ID IS NULL THEN
       DBMS_OUTPUT.PUT_LINE('ERROR: USER ID cannot be NULL. Please enter a valid User ID.');
       RETURN;
    END IF;

    -- Check if the user ID exists
    SELECT User_Name INTO v_User_Name
    FROM Users
    WHERE User_ID = p_User_ID;

 
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Expense ID | User ID |     User Name       | Group ID |     Group Name     |    Amount    |   Date    |  Category      |  Description  ');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------------------------------------------------');

    -- Retrieve and display expenses for the specified user
    FOR rec IN (
        SELECT e.Expense_ID, e.User_ID, u.User_Name, e.Group_ID, g.Group_Name, e.Amount,
        e.category,TO_CHAR(e.Expense_Date, 'YYYY-MM-DD') AS Expense_Date,
        NVL(e.Description, 'No Description') AS Description
        FROM Expenses e
        JOIN Users u ON e.User_ID = u.User_ID
        JOIN Groups g ON e.Group_ID = g.Group_ID
        WHERE e.User_ID = p_User_ID
        ORDER BY e.Expense_ID, e.Expense_Date DESC
    ) LOOP
        v_Total_Expenses := v_Total_Expenses + rec.Amount;
        DBMS_OUTPUT.PUT_LINE(
            LPAD(rec.Expense_ID, 10) || ' | ' ||
            LPAD(rec.User_ID, 8) || ' | ' ||
            RPAD(rec.User_Name, 18) || ' | ' ||
            LPAD(rec.Group_ID, 8) || ' | ' ||
            RPAD(rec.Group_Name, 18) || ' | ' ||
            LPAD(TO_CHAR(rec.Amount, '9999999999.99'), 13) || ' | ' ||  
            RPAD(rec.Expense_Date, 11) || ' | ' ||
            RPAD(rec.category, 14) || ' | ' ||  
            RPAD(SUBSTR(rec.Description, 1, 30), 30)  
        );
    END LOOP;

    -- If no records found, display a message
    IF v_Total_Expenses = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No expenses found for User ID ' || p_User_ID || '. Please check the user ID and try again.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total Expenses for User ' || v_User_Name || ' (ID ' || p_User_ID || '): ' || TO_CHAR(v_Total_Expenses, '9999999999.99'));
        DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------------------------------------------------');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: User ID ' || p_User_ID || ' does not exist. Please enter a valid User ID.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END View_Expenses_By_User;






create or replace PROCEDURE View_Expenses_By_Group (
    p_Group_ID IN NUMBER DEFAULT NULL
) IS 
    v_Group_Name VARCHAR2(100);
    v_Total_Expenses NUMBER := 0;
BEGIN

    -- Validate Group ID input
    IF p_Group_ID IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Group ID cannot be NULL. Please enter a valid Group ID');
        RETURN;
    END IF;

    -- Check if the group ID exists
    BEGIN
        SELECT Group_Name INTO v_Group_Name
        FROM Groups
        WHERE Group_ID = p_Group_ID;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Error: Group ID ' || p_Group_ID || ' does not exist. Please enter a valid Group ID.');
            RETURN;
    END;

    -- Output table header
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Expense ID | User ID |     User Name       | Group ID |     Group Name     |   Amount   |   Date        | Category      | Description ');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------------------------');

    -- Retrieve and display expenses for the specified group
    FOR rec IN (
        SELECT e.Expense_ID, e.User_ID, u.User_Name,  e.Group_ID,  g.Group_Name, e.Category, e.Amount, 
            TO_CHAR(e.Expense_Date, 'YYYY-MM-DD') AS Expense_Date,
            NVL(e.Description, 'No Description') AS Description
        FROM Expenses e
        JOIN Users u ON e.User_ID = u.User_ID
        JOIN Groups g ON e.Group_ID = g.Group_ID
        WHERE e.Group_ID = p_Group_ID
        ORDER BY e.Expense_ID
    ) LOOP
        v_Total_Expenses := v_Total_Expenses + rec.Amount;

        -- Output each expense record with Category and Description side by side
        DBMS_OUTPUT.PUT_LINE(
            LPAD(rec.Expense_ID, 10) || ' | ' ||
            LPAD(rec.User_ID, 8) || ' | ' ||
            RPAD(rec.User_Name, 18) || ' | ' ||
            LPAD(rec.Group_ID, 8) || ' | ' ||
            RPAD(rec.Group_Name, 18) || ' | ' ||
            LPAD(TO_CHAR(rec.Amount, '9999999999.99'), 12) || ' | ' ||
            RPAD(rec.Expense_Date, 11) || ' | ' ||
            RPAD(rec.Category, 14) || ' | ' ||  -- Display Category and Description together
            RPAD(SUBSTR(rec.Description, 1, 50), 50)
        );
    END LOOP;

    -- If no records found, display a message
    IF v_Total_Expenses = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No expenses found for Group ID ' || p_Group_ID || '. Please check the group ID and try again.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total Expenses for Group ' || v_Group_Name || ' (ID ' || p_Group_ID || '): ' || TO_CHAR(v_Total_Expenses, '9999999999.99'));
        DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------------------------');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END View_Expenses_By_Group;








create or replace PROCEDURE Split_Expense_By_Group(
    p_Group_ID IN NUMBER DEFAULT NULL,
    p_Expense_ID IN NUMBER DEFAULT NULL
) AS
    TYPE t_user_array IS TABLE OF VARCHAR2(100) INDEX BY BINARY_INTEGER;
    TYPE t_number_array IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

    v_User_Names t_user_array;
    v_User_IDs t_number_array;
    v_Paid_Amounts t_number_array;
    v_Paid_Debts t_number_array;
    v_Balances t_number_array;
    v_Existing_Debts t_number_array;
    v_Total_Amount NUMBER := 0;
    v_User_Count NUMBER := 0;
    v_Equal_Share NUMBER;
    v_Group_Name VARCHAR2(100);

BEGIN
    -- Initial checks
    IF p_Group_ID IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Group ID cannot be NULL. Please enter valid Group ID');
        RETURN;
    END IF;

    -- Get group name
    SELECT Group_Name INTO v_Group_Name
    FROM Groups
    WHERE Group_ID = p_Group_ID;

    -- Calculate total amount for all unprocessed expenses in the group
    SELECT NVL(SUM(Amount), 0)
    INTO v_Total_Amount
    FROM Expenses
    WHERE Group_ID = p_Group_ID
    AND Processed = 'N'
    AND (p_Expense_ID IS NULL OR Expense_ID = p_Expense_ID);

    -- If no expenses found or already processed, exit
    IF v_Total_Amount = 0 THEN
        DBMS_OUTPUT.PUT_LINE('INFO: No unprocessed expenses found.');
        RETURN;
    END IF;

    -- Get all group members and their contributions
    FOR user_rec IN (
        SELECT u.User_ID, u.User_Name,
            NVL((
                SELECT SUM(Amount)
                FROM Expenses
                WHERE User_ID = u.User_ID
                AND Group_ID = p_Group_ID
                AND Processed = 'N'
                AND (p_Expense_ID IS NULL OR Expense_ID = p_Expense_ID)
            ), 0) AS Paid_Amount
        FROM Users u
        JOIN Group_Members gm ON u.User_ID = gm.User_ID
        WHERE gm.Group_ID = p_Group_ID
        ORDER BY u.User_ID
    ) LOOP
        v_User_Count := v_User_Count + 1;
        v_User_Names(v_User_Count) := user_rec.User_Name;
        v_User_IDs(v_User_Count) := user_rec.User_ID;
        v_Paid_Amounts(v_User_Count) := Round(user_rec.Paid_Amount, 2);
    END LOOP;

    IF v_User_Count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('INFO: No users found in the group.');
        RETURN;
    END IF;

    -- Calculate equal share
    v_Equal_Share := Round(v_Total_Amount / v_User_Count, 2);

    -- Calculate balances for each user
    FOR i IN 1..v_User_Count LOOP
        v_Balances(i) := v_Paid_Amounts(i) - v_Equal_Share;
    END LOOP;

    -- Display summary header
    DBMS_OUTPUT.PUT_LINE('==============================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                         Expense Split Summary for Group: ' || v_Group_Name);
    IF p_Expense_ID IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('                         Expense ID: ' || p_Expense_ID);
    END IF;
    DBMS_OUTPUT.PUT_LINE('==============================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Total Amount: ' || v_Total_Amount);
    DBMS_OUTPUT.PUT_LINE('Equal Share per Person: ' || v_Equal_Share);
    DBMS_OUTPUT.PUT_LINE('Number of Members: ' || v_User_Count);
    DBMS_OUTPUT.PUT_LINE('==============================================================================================================');
    DBMS_OUTPUT.PUT_LINE('User Name                | User ID  | Paid Amount  | Share       | Balance');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------------------------------------');

    -- Display user details
    FOR i IN 1..v_User_Count LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_User_Names(i), 25) || ' | ' ||
            LPAD(v_User_IDs(i), 8) || ' | ' ||
            LPAD(TO_CHAR(v_Paid_Amounts(i), '999,999.00'), 11) || ' | ' ||
            LPAD(TO_CHAR(v_Equal_Share, '999,999.00'), 10) || ' | ' ||
            CASE
                WHEN v_Balances(i) < 0 THEN 'Owes' || TO_CHAR(ABS(v_Balances(i)), '999,999.00')
                WHEN v_Balances(i) > 0 THEN 'Owed' || TO_CHAR(v_Balances(i), '999,999.00')
                ELSE 'Settled'
            END
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------------------------------------');

    -- Process and record debts
    FOR i IN 1..v_User_Count LOOP
        IF v_Balances(i) < 0 THEN -- User owes money
            FOR j IN 1..v_User_Count LOOP
                IF v_Balances(j) > 0 THEN -- User is owed money
                    DECLARE
                        v_Transfer_Amount NUMBER;
                    BEGIN
                        v_Transfer_Amount := LEAST(ABS(v_Balances(i)), v_Balances(j));
                        v_Transfer_Amount := ROUND(v_Transfer_Amount, 2);

                        IF v_Transfer_Amount > 0 THEN
                            -- Create debt record
                            INSERT INTO Debts ( From_User_ID,  To_User_ID, Amount, Settled, Expense_I)
                            VALUES (  v_User_IDs(i), v_User_IDs(j), v_Transfer_Amount, 'N', p_Expense_ID );

                            -- Update balances
                            v_Balances(i) := v_Balances(i) + v_Transfer_Amount;
                            v_Balances(j) := v_Balances(j) - v_Transfer_Amount;

                            DBMS_OUTPUT.PUT_LINE('INFO: ' || v_User_Names(i) || ' owes ' ||
                                TO_CHAR(v_Transfer_Amount, '999,999.00') || ' to ' || v_User_Names(j));
                        END IF;
                    END;
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    -- Mark relevant expenses as processed
    UPDATE Expenses
    SET Processed = 'Y'
    WHERE Group_ID = p_Group_ID
    AND Processed = 'N'
    AND (p_Expense_ID IS NULL OR Expense_ID = p_Expense_ID);

    DBMS_OUTPUT.PUT_LINE('============================================================================================');
    DBMS_OUTPUT.PUT_LINE('Expense split calculation and debt recording completed successfully.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Invalid Group ID: ' || p_Group_ID);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
END;








create or replace PROCEDURE View_Debts_By_User(
    p_User_ID IN NUMBER DEFAULT NULL
) AS
    -- Cursor to retrieve debt information where the specified user is involved
    CURSOR debt_cursor IS
        SELECT  d.Debt_ID,  u1.User_ID AS Owing_User_ID,
            u1.User_Name AS Owing_User_Name,
            u2.User_ID AS Owed_User_ID,
            u2.User_Name AS Owed_User_Name,
            d.Amount,d.Settled
        FROM Debts d
            JOIN Users u1 ON d.From_User_ID = u1.User_ID
            JOIN Users u2 ON d.To_User_ID = u2.User_ID
        WHERE 
            d.From_User_ID = p_User_ID  -- User is the one owing the debt
            OR d.To_User_ID = p_User_ID  -- User is the one owed the debt
        ORDER BY 
             d.Debt_ID;  -- Order by Debt_ID

    -- Variables to count settled and unsettled debts
    v_Settled_Count NUMBER := 0;
    v_Unsettled_Count NUMBER := 0;

    -- Variable to store user's name
    v_User_Name VARCHAR2(100);
    
BEGIN

    IF p_User_ID IS NULL THEN 
   DBMS_OUTPUT.PUT_LINE('ERROR: USER ID cannot be NULL.please Enter valid User ID');
    RETURN ;
    END IF;
    
    
    -- Fetch the user's name from the Users table
    SELECT User_Name INTO v_User_Name 
    FROM Users 
    WHERE User_ID = p_User_ID;

    -- Check if the user ID is valid
    IF p_User_ID IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: User ID cannot be NULL.');
        RETURN;
    END IF;

    -- Header for the debts view
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                         Debt Summary for User: ' || v_User_Name || ' (ID: ' || p_User_ID || ')');
    DBMS_OUTPUT.PUT_LINE('=====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Debt ID | Owing_User_ID   | Owing_User_Name     | Owed_User_ID    | Owed_User_Name      |   Amount   | Status');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------');

    -- Iterate through the debts
    FOR debt_rec IN debt_cursor LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(debt_rec.Debt_ID, 7) || ' | ' ||   -- Add Debt_ID
            RPAD(debt_rec.Owing_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owing_User_Name, 20) || ' | ' ||
            RPAD(debt_rec.Owed_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owed_User_Name, 20) || ' | ' ||
            LPAD(TO_CHAR(debt_rec.Amount, 'FM9999999.00'), 10) || ' | ' ||  -- Align Amount to the right
            RPAD(CASE 
                    WHEN debt_rec.Settled = 'Y' THEN 'Settled'
                    ELSE 'Unsettled'
                 END, 9)  -- Align Status to the left
        );

        -- Count settled and unsettled debts
        IF debt_rec.Settled = 'Y' THEN
            v_Settled_Count := v_Settled_Count + 1;
        ELSE
            v_Unsettled_Count := v_Unsettled_Count + 1;
        END IF;
    END LOOP;

    -- Summary of settled and unsettled debts
    DBMS_OUTPUT.PUT_LINE('=============================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Total Settled Debts: ' || v_Settled_Count);
    DBMS_OUTPUT.PUT_LINE('Total Unsettled Debts: ' || v_Unsettled_Count);
    DBMS_OUTPUT.PUT_LINE('==============================================================================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('INFO: No debts found for the specified user.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: An unexpected error occurred: ' || SQLERRM);
END View_Debts_By_User;











create or replace PROCEDURE View_Debts_By_Group(
    p_Group_ID IN NUMBER DEFAULT NULL
) AS
    -- Variable to hold the group name
    v_Group_Name VARCHAR2(100);
    
    -- Cursor to retrieve debt information for the specified group
    CURSOR debt_cursor IS
        SELECT  d.Debt_ID,
            u1.User_ID AS Owing_User_ID,
            u1.User_Name AS Owing_User,
            u2.User_ID AS Owed_User_ID,
            u2.User_Name AS Owed_User,
            d.Amount,d.Settled
        FROM  Debts d
            JOIN Group_Members gm1 ON d.From_User_ID = gm1.User_ID
            JOIN Group_Members gm2 ON d.To_User_ID = gm2.User_ID
            JOIN Users u1 ON gm1.User_ID = u1.User_ID
            JOIN Users u2 ON gm2.User_ID = u2.User_ID
        WHERE
            gm1.Group_ID = p_Group_ID
            AND gm2.Group_ID = p_Group_ID
        ORDER BY d.Debt_ID;
    
    -- Variables to count settled and unsettled debts
    v_Settled_Count NUMBER := 0;
    v_Unsettled_Count NUMBER := 0;
    
    -- Variable to check if the group exists
    v_Group_Exists NUMBER;
    
    -- Flag for new entry status
    v_New_Entry VARCHAR2(10);
BEGIN
    -- Check for null group ID first
    IF p_Group_ID IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Group ID cannot be NULL. Please enter a valid Group ID.');
        RETURN;
    END IF;
    
    -- Check if the group exists before proceeding
    SELECT COUNT(*) INTO v_Group_Exists
    FROM Groups
    WHERE Group_ID = p_Group_ID;
    
    IF v_Group_Exists = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Group ID ' || p_Group_ID || ' does not exist. Please provide a valid Group ID.');
        RETURN;
    END IF;
    
    -- Retrieve the group name based on the Group ID
    SELECT Group_Name INTO v_Group_Name
    FROM Groups
    WHERE Group_ID = p_Group_ID;
    
    -- Header for the debts view with Group Name
    DBMS_OUTPUT.PUT_LINE('===================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                         Debt Summary for Group: ' || v_Group_Name || ' (ID: ' || p_Group_ID || ')');
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Debt ID | Owing User ID   | Owing User            | Owed User ID    | Owed User     | Amount   |      Status');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------');
   
    -- Iterate through the debts
    FOR debt_rec IN debt_cursor LOOP
        -- Check if it's a new debt (just added)
        IF debt_rec.Settled IS NULL THEN
            v_New_Entry := '(new entry)';
        ELSE
            v_New_Entry := '';
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(debt_rec.Debt_ID, 7) || ' | ' ||
            RPAD(debt_rec.Owing_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owing_User, 20) || ' | ' ||
            RPAD(debt_rec.Owed_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owed_User, 17) || ' | ' ||
            LPAD(TO_CHAR(debt_rec.Amount, 'FM9999999.00'), 7) || ' | ' ||
            RPAD(CASE 
                    WHEN debt_rec.Settled = 'Y' THEN 'Settled'
                    WHEN debt_rec.Settled = 'N' THEN 'Unsettled'
                    ELSE 'Unsettled ' || v_New_Entry
                 END, 8)
        );
        
        -- Count settled and unsettled debts
        IF debt_rec.Settled = 'Y' THEN
            v_Settled_Count := v_Settled_Count + 1;
        ELSE
            v_Unsettled_Count := v_Unsettled_Count + 1;
        END IF;
    END LOOP;
    
    -- Summary of settled and unsettled debts
    IF v_Settled_Count = 0 AND v_Unsettled_Count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No debts found for this group.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('==================================================================================================================');
        DBMS_OUTPUT.PUT_LINE('Total Settled Debts: ' || v_Settled_Count);
        DBMS_OUTPUT.PUT_LINE('Total Unsettled Debts: ' || v_Unsettled_Count);
        DBMS_OUTPUT.PUT_LINE('===================================================================================================================');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: An unexpected error occurred: ' || SQLERRM);
END View_Debts_By_Group;










create or replace PROCEDURE View_All_Debts AS
    -- Cursor to retrieve debt information for all users
    CURSOR debt_cursor IS
        SELECT DISTINCT d.Debt_ID,
            u1.User_ID AS Owing_User_ID,
            u1.User_Name AS Owing_User_Name,
            u2.User_ID AS Owed_User_ID,
            u2.User_Name AS Owed_User_Name,
            d.Amount, d.Settled
        FROM Debts d
            JOIN Users u1 ON d.From_User_ID = u1.User_ID
            JOIN Users u2 ON d.To_User_ID = u2.User_ID
            JOIN Group_Members gm1 ON u1.User_ID = gm1.User_ID
            JOIN Group_Members gm2 ON u2.User_ID = gm2.User_ID
        ORDER BY d.Debt_ID;

    -- Variables to count total settled and unsettled debts across all users
    v_Total_Settled_Count NUMBER := 0;
    v_Total_Unsettled_Count NUMBER := 0;
 
BEGIN
    -- Header for the unified debts table view
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                                            Complete Debts Summary');
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Debt ID | Owing_User_ID   | Owing_User_Name     | Owed_User_ID    | Owed_User_Name      |   Amount   | Status');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------');

    -- Iterate through the debts and display each debt's information
    FOR debt_rec IN debt_cursor LOOP
        -- Display the debt information
        DBMS_OUTPUT.PUT_LINE(
            RPAD(debt_rec.Debt_ID, 7) || ' | ' ||
            RPAD(debt_rec.Owing_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owing_User_Name, 20) || ' | ' ||
            RPAD(debt_rec.Owed_User_ID, 15) || ' | ' ||
            RPAD(debt_rec.Owed_User_Name, 20) || ' | ' ||
            LPAD(TO_CHAR(debt_rec.Amount, 'FM9999999.00'), 10) || ' | ' ||
            RPAD(CASE 
                    WHEN debt_rec.Settled = 'Y' THEN 'Settled'
                    ELSE 'Unsettled'
                 END, 9)
        );

        -- Count total settled and unsettled debts
        IF debt_rec.Settled = 'Y' THEN
            v_Total_Settled_Count := v_Total_Settled_Count + 1;
        ELSE
            v_Total_Unsettled_Count := v_Total_Unsettled_Count + 1;
        END IF;
    END LOOP;

    -- Print the overall summary for all debts
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Total Settled Debts: ' || v_Total_Settled_Count);
    DBMS_OUTPUT.PUT_LINE('Total Unsettled Debts: ' || v_Total_Unsettled_Count);
    DBMS_OUTPUT.PUT_LINE('====================================================================================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('STATUS  : Error');
        DBMS_OUTPUT.PUT_LINE('MESSAGE : An unexpected error occurred: ' || SQLERRM);
END View_All_Debts;










create or replace PROCEDURE User_Monthly_Spending_Report (
    p_user_id NUMBER DEFAULT NULL
) IS
    -- Variable to hold the user's name
    v_user_name VARCHAR2(100);

    -- Cursor to fetch spending by month, group, category, and description for the specified user
    CURSOR monthly_trend_cursor IS
        SELECT TO_CHAR(e.expense_date, 'YYYY-MM') AS month,
               TO_CHAR(e.expense_date, 'Month YYYY') AS month_name,
               e.expense_id,g.group_name,e.category, e.description, e.amount AS amount_spent
        FROM Expenses e
        JOIN Groups g ON e.group_id = g.group_id
        WHERE e.user_id = p_user_id
        ORDER BY month, g.group_name, e.category, e.expense_id;

    -- Variables to track the current month and monthly total in the loop
    v_current_month VARCHAR2(7) := NULL;
    v_month_total NUMBER := 0;

BEGIN
    -- Validate the input parameter
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'User ID must be provided.');
    END IF;

    -- Retrieve the user's name based on the provided user ID
    BEGIN
        SELECT user_name INTO v_user_name
        FROM Users
        WHERE user_id = p_user_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'User not found with ID ' || p_user_id);
    END;

   
    DBMS_OUTPUT.PUT_LINE('=================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                                   Monthly Spending Report                                       ');
    DBMS_OUTPUT.PUT_LINE('=================================================================================================');
    DBMS_OUTPUT.PUT_LINE('Report for User: ' || v_user_name || ' (User ID: ' || p_user_id || ')');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Month           | Expense ID | Group Name        | Category         | Amount Spent | Description');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------------------------------');

    -- Process each record in the cursor
    FOR rec IN monthly_trend_cursor LOOP
        -- Check if we're on a new month to reset the month total
        IF v_current_month IS NULL OR v_current_month != rec.month THEN
            -- Display the monthly total for the previous month, if any
            IF v_current_month IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------------------------------------');
                DBMS_OUTPUT.PUT_LINE('Total for ' || v_current_month || ': ' || TO_CHAR(v_month_total, '999G999D99'));
                DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------');
            END IF;

            -- Start tracking for the new month
            v_current_month := rec.month;
            v_month_total := 0;
        END IF;

        -- Display the expense details for the current record
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.month_name, 14) || ' | ' || 
            LPAD(rec.expense_id, 10) || ' | ' || 
            RPAD(rec.group_name, 18) || ' | ' || 
            RPAD(rec.category, 16) || ' | ' || 
            LPAD(TO_CHAR(rec.amount_spent, '999G999D99'), 12) || ' | ' ||
            RPAD(rec.description, 20)
        );

        -- Add to the monthly total
        v_month_total := v_month_total + rec.amount_spent;
    END LOOP;

    -- Display the total for the last month after exiting the loop
    IF v_current_month IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total for ' || v_current_month || ': ' || TO_CHAR(v_month_total, '999G999D99'));
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------------------------------------');
    END IF;

    -- Display the footer
    DBMS_OUTPUT.PUT_LINE('=================================================================================================');
    DBMS_OUTPUT.PUT_LINE('                                 End of Monthly Spending Report                                  ');
    DBMS_OUTPUT.PUT_LINE('=================================================================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END;








create or replace PROCEDURE User_Debt_Report (
    p_user_id NUMBER DEFAULT NULL
) IS
    -- Variable to hold the user's name
    v_user_name VARCHAR2(100);

    -- Variables to calculate totals
    v_total_to_pay NUMBER := 0;
    v_total_to_receive NUMBER := 0;

    -- Cursor to fetch debts where the user owes money
    CURSOR debts_to_pay_cursor IS
        SELECT d.debt_id,
               u.user_name AS to_user_name,
               d.amount,
               CASE d.settled WHEN 'Y' THEN 'Settled' ELSE 'Unsettled' END AS status,
               NVL(TO_CHAR(d.settlement_date, 'DD-MON-YYYY'), 'N/A') AS settlement_date
        FROM Debts d
        JOIN Users u ON d.To_User_ID = u.user_id
        WHERE d.From_User_ID = p_user_id
        ORDER BY d.debt_id;

    -- Cursor to fetch debts where the user is owed money
    CURSOR debts_to_receive_cursor IS
        SELECT d.debt_id,
               u.user_name AS from_user_name,
               d.amount,
               CASE d.settled WHEN 'Y' THEN 'Settled' ELSE 'Unsettled' END AS status,
               NVL(TO_CHAR(d.settlement_date, 'DD-MON-YYYY'), 'N/A') AS settlement_date
        FROM Debts d
        JOIN Users u ON d.From_User_ID = u.user_id
        WHERE d.To_User_ID = p_user_id
        ORDER BY d.debt_id;

BEGIN
    -- Validate the input parameter
    IF p_user_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'User ID must be provided.');
    END IF;

    -- Retrieve the user's name based on the provided user ID
    BEGIN
        SELECT user_name INTO v_user_name
        FROM Users
        WHERE user_id = p_user_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'User not found with ID ' || p_user_id);
    END;

   
    DBMS_OUTPUT.PUT_LINE('=====================================================================');
    DBMS_OUTPUT.PUT_LINE('                           Debt Tracking Report                      ');
    DBMS_OUTPUT.PUT_LINE('=====================================================================');
    DBMS_OUTPUT.PUT_LINE('Report for User: ' || v_user_name || ' (User ID: ' || p_user_id || ')');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');

    DBMS_OUTPUT.PUT_LINE('Debts to Pay:');
    DBMS_OUTPUT.PUT_LINE('Debt ID | To User         | Amount    | Status     | Settlement Date');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
    FOR rec IN debts_to_pay_cursor LOOP
        DBMS_OUTPUT.PUT_LINE(
            LPAD(rec.debt_id, 7) || ' | ' ||
            RPAD(rec.to_user_name, 16) || ' | ' || 
            LPAD(TO_CHAR(rec.amount, '999G999D99'), 10) || ' | ' || 
            RPAD(rec.status, 10) || ' | ' || 
            rec.settlement_date
        );
        -- Add to total only if unsettled
        IF rec.status = 'Unsettled' THEN
            v_total_to_pay := v_total_to_pay + rec.amount;
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Debt to Pay: ' || LPAD(TO_CHAR(v_total_to_pay, '999G999D99'), 10));

    -- Section: Debts the user is owed
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Debts to Receive:');
    DBMS_OUTPUT.PUT_LINE('Debt ID | From User       | Amount    | Status     | Settlement Date');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
    FOR rec IN debts_to_receive_cursor LOOP
        DBMS_OUTPUT.PUT_LINE(
            LPAD(rec.debt_id, 7) || ' | ' ||
            RPAD(rec.from_user_name, 16) || ' | ' || 
            LPAD(TO_CHAR(rec.amount, '999G999D99'), 10) || ' | ' || 
            RPAD(rec.status, 10) || ' | ' || 
            rec.settlement_date
        );
        -- Add to total only if unsettled
        IF rec.status = 'Unsettled' THEN
            v_total_to_receive := v_total_to_receive + rec.amount;
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Total Debt to Receive: ' || LPAD(TO_CHAR(v_total_to_receive, '999G999D99'), 10));
    DBMS_OUTPUT.PUT_LINE('=====================================================================');
    DBMS_OUTPUT.PUT_LINE('                       End of Debt Tracking Report                   ');
    DBMS_OUTPUT.PUT_LINE('=====================================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END;







create or replace PROCEDURE Saving_Recommendation (
    p_user_id NUMBER,
    p_savings_percentage NUMBER DEFAULT 20  -- Default savings percentage is 20%
) IS

    v_user_name VARCHAR2(100);
    v_total_spent NUMBER := 0;
    v_suggested_saving_goal NUMBER := 0;
    v_highest_category_spent NUMBER := 0;
    v_total_debt NUMBER := 0;

    -- Type and variable for tied highest spending categories
    TYPE Category_Table IS TABLE OF VARCHAR2(50);
    v_highest_categories Category_Table := Category_Table();

    -- Cursor for spending categories
    CURSOR category_cursor IS
        SELECT CATEGORY, SUM(AMOUNT) AS total_spent
        FROM Expenses
        WHERE User_ID = p_user_id
        GROUP BY CATEGORY
        ORDER BY total_spent DESC;

BEGIN
    -- Fetch the user details
    SELECT User_Name
    INTO v_user_name
    FROM Users
    WHERE User_ID = p_user_id;

    -- Calculate total spending for the user
    SELECT NVL(SUM(Amount), 0)
    INTO v_total_spent
    FROM Expenses
    WHERE User_ID = p_user_id;

    -- Calculate total debt of the user
    SELECT NVL(SUM(Amount), 0)
    INTO v_total_debt
    FROM Debts
    WHERE From_User_ID = p_user_id AND Settled = 'N';

    -- Validate savings percentage (must be between 0 and 100)
    IF p_savings_percentage < 0 OR p_savings_percentage > 100 THEN
        DBMS_OUTPUT.PUT_LINE('Error: Invalid savings percentage. Please provide a value between 0 and 100.');
        RETURN;
    END IF;

    -- Suggest savings goal based on user-defined percentage
    v_suggested_saving_goal := v_total_spent * (p_savings_percentage / 100);

    -- Identify the category with the highest spending and handle ties
    FOR rec IN category_cursor LOOP
        IF rec.total_spent > v_highest_category_spent THEN
            v_highest_category_spent := rec.total_spent;
            v_highest_categories.DELETE;
            v_highest_categories.EXTEND;
            v_highest_categories(v_highest_categories.LAST) := rec.category;
        ELSIF rec.total_spent = v_highest_category_spent THEN
            v_highest_categories.EXTEND;
            v_highest_categories(v_highest_categories.LAST) := rec.category;
        END IF;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('                    Saving Recommendations                    ');
    DBMS_OUTPUT.PUT_LINE('========================================================================');
    DBMS_OUTPUT.PUT_LINE('User: ' || v_user_name || ' (User ID: ' || p_user_id || ')');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------');

    -- Financial Overview
    DBMS_OUTPUT.PUT_LINE('Total Spending:          ' || TO_CHAR(v_total_spent, '999,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('Outstanding Debt:        ' || TO_CHAR(v_total_debt, '999,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------------------------------');

    -- Suggested Saving Goal
    DBMS_OUTPUT.PUT_LINE('Suggested Savings Goal:  ' || TO_CHAR(v_suggested_saving_goal, '999,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------');

    -- Category with highest spending
    IF v_highest_category_spent > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Highest Spending Categories: ');
        FOR i IN 1..v_highest_categories.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('- ' || v_highest_categories(i));
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Amount Spent :     ' || TO_CHAR(v_highest_category_spent, '999,999,999.00'));
        DBMS_OUTPUT.PUT_LINE('Recommendation: Consider reducing spending in the above categories to optimize savings.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('No spending data available to suggest categories for reduction.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------');

    -- Actionable Suggestions
    DBMS_OUTPUT.PUT_LINE('Actionable Suggestions:');
    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('1. Review your spending in the highest spending categories and consider cutting back.');
    DBMS_OUTPUT.PUT_LINE('2. Focus on reducing non-essential expenses and prioritize savings.');
    DBMS_OUTPUT.PUT_LINE('3. Set a realistic monthly savings target based on your income and spending pattern.');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Keep Tracking Your Progress!');
    DBMS_OUTPUT.PUT_LINE('================================================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Error: No user found with the provided User ID: ' || p_user_id || '. Please provide a valid User ID.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
END;






