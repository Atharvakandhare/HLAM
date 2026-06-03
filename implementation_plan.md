# Implementation Plan — Multi-Company & Team Hierarchy System

We will implement a proper role hierarchy, multi-company support, team management, email credentials delivery, and a modern React.js Admin Web Dashboard to manage these structures.

---

## 1. Role & Access Hierarchy

The application will transition to a 5-tier role hierarchy:

| Role | Dashboard Access | Responsibilities |
|---|---|---|
| **System Admin** (`system_admin`) | Web (All Companies + Own) | Manages multiple Companies & Company Admins. Manages own company (Hirelyft). |
| **Company Admin** (`company_admin`) | Web (Own Company Only) | Creates Teams. Assigns Managers/Team Leaders. Adds employees. |
| **Manager** (`manager`) | Mobile (Mark Attend.) + Web (Team Stats) | Assigns Team Leaders. Registers/adds Team Members under their team. |
| **Team Leader** (`team_leader`) | Mobile (Mark Attend.) + Web (Team Stats) | Registers/adds Team Members under their team. |
| **Employee** (`employee`) | Mobile (Mark Attendance Only) | Marks check-in/out. Views only their own attendance and leaves. |

---

## 2. Database Schema Upgrades (Sequelize & MySQL)

We will define two new models and modify the existing `User` model.

### New Model: `Company` [NEW]
- `id` (INT, Primary Key)
- `name` (STRING, Unique)
- `isActive` (BOOLEAN, default true)

### New Model: `Team` [NEW]
- `id` (INT, Primary Key)
- `name` (STRING)
- `companyId` (INT, Foreign Key referencing `companies.id`)

### Modified Model: `User`
- `companyId` (INT, Foreign Key referencing `companies.id`, nullable)
- `teamId` (INT, Foreign Key referencing `teams.id`, nullable)
- `role`: Changed ENUM from `('employee', 'admin')` to `('system_admin', 'company_admin', 'manager', 'team_leader', 'employee')`.

---

## 3. Proposed Backend Changes

### [NEW] [Company.js](file:///d:/Attendance_Management_App/backend/models/Company.js)
- Define standard `Company` schema.

### [NEW] [Team.js](file:///d:/Attendance_Management_App/backend/models/Team.js)
- Define standard `Team` schema.

### [MODIFY] [User.js](file:///d:/Attendance_Management_App/backend/models/User.js)
- Update `role` ENUM definition.
- Add `companyId` and `teamId` fields.

### [MODIFY] [associations.js](file:///d:/Attendance_Management_App/backend/associations.js)
- Associate `Company` with `Team` (hasMany) and `User` (hasMany).
- Associate `Team` with `User` (hasMany).

### [MODIFY] [server.js](file:///d:/Attendance_Management_App/backend/server.js)
- In `startServer`, add automatic migration queries to alter the `role` enum in MySQL and add `company_id` and `team_id` columns if they don't exist.
- Auto-create the default company "Hirelyft India Pvt. Ltd.".
- Associate all existing users with "Hirelyft India Pvt. Ltd.".
- Update `admin@hirelyft.in` role to `system_admin`.

### [MODIFY] [auth.js](file:///d:/Attendance_Management_App/backend/middleware/auth.js)
- Replace `adminOnly` with tiered middlewares:
  - `systemAdminOnly`
  - `companyAdminOnly` (grants access to system_admin & company_admin)
  - `managerOrTLOnly` (grants access to system_admin, company_admin, manager, & team_leader)

### [MODIFY] [authController.js](file:///d:/Attendance_Management_App/backend/controllers/authController.js)
- Update login response and `/auth/me` endpoint to return company name, team name, manager's name, and team leader's name, so mobile/web users can see where they belong.

### [MODIFY] [adminController.js](file:///d:/Attendance_Management_App/backend/controllers/adminController.js)
- Update `listUsers` and `createUser` to support the new hierarchy rules.
- Add controllers for:
  - System Admin: Create/List Companies and Company Admins.
  - Company Admin: Create/List Teams.
- Configure automatic emails with login credentials during creation of any user.

### [MODIFY] [attendanceController.js](file:///d:/Attendance_Management_App/backend/controllers/attendanceController.js)
- Update `checkIn` so only `system_admin` and `company_admin` are blocked from checking in (Managers and TLs can check-in/out).
- Filter attendance lists:
  - System Admin: Views Hirelyft attendance.
  - Company Admin: Views all records in their company.
  - Manager/TL: Views all records for members belonging to their team.
  - Employee: Views only their own records.

### [MODIFY] [adminRoutes.js](file:///d:/Attendance_Management_App/backend/routes/adminRoutes.js)
- Add endpoints for Company and Team management.

---

## 4. Proposed React.js Admin Web Dashboard (Admin-Web-dashboard)

We will initialize and construct the web dashboard using **React.js (Vite)** under `d:\Attendance_Management_App\Admin-Web-dashboard`.

### Setup & Tools
- Run Vite configuration with Vanilla CSS styling.
- Design: Clean modern dashboard, dark mode harmonies, sleek sidebar navigation, responsive layout.

### Dashboard Layout & Routes
- **Login Screen**: Authenticates all dashboard users.
- **Sidebar**:
  - *Overview / Dashboard*: Displays key stats (System Admin sees counts across all companies; Company Admin sees counts for their company).
  - *Companies* (System Admin Only): Add and manage other companies and their admins.
  - *Teams* (Company Admin Only): Add/create teams.
  - *Users / Employees*: Add and manage employees (Company Admins can assign Managers/TLs; Managers/TLs can manage their team members).
  - *Attendance Records*: View logs, filter by employee/team, view map location, and export reports.
  - *Leave Applications*: View, approve, or reject leave requests.
  - *Marketing Location Tracking*: Visual trail maps of marketing department routes.
  - *Profile*: View own details and change password.

---

## 5. Proposed Flutter Mobile Application Changes

### [MODIFY] [user.dart](file:///d:/Attendance_Management_App/Mobile_App/lib/models/user.dart)
- Parse new attributes: `companyName`, `teamName`, `managerName`, `teamLeaderName`.

### [MODIFY] [dashboard_screen.dart](file:///d:/Attendance_Management_App/Mobile_App/lib/screens/dashboard_screen.dart)
- Update `_isAdmin` check: `role == 'system_admin' || role == 'company_admin'`.
- Display company name, manager name, and team leader name in the employee details section.

### [MODIFY] [add_employee_screen.dart](file:///d:/Attendance_Management_App/Mobile_App/lib/screens/add_employee_screen.dart)
- Update UI to select role (Manager, Team Leader, Employee) and select team from a list of teams fetched from the backend.

---

## Verification Plan

### Automated
- Run `flutter analyze` inside the Flutter app.
- Build the React Web Dashboard to verify there are no compilation errors.

### Manual
1. **System Admin Flow**:
   - Log in as `admin@hirelyft.in` on Web.
   - Create a new Company "Tesla Inc." and assign a Company Admin `admin@tesla.com`.
   - Verify that `admin@tesla.com` receives their email credentials.
2. **Company Admin Flow**:
   - Log in as `admin@tesla.com` on Web.
   - Create a team "Marketing Team".
   - Add a Manager `manager@tesla.com`.
3. **Manager Flow**:
   - Log in as `manager@tesla.com` on Mobile/Web.
   - Register a Team Member `employee@tesla.com` under the Marketing Team.
4. **Attendance Marking & Visibility Flow**:
   - Log in as `employee@tesla.com` on Mobile.
   - Mark check-in with selfie.
   - Verify that `manager@tesla.com` and `admin@tesla.com` can view the check-in record, while the employee only sees their own.
