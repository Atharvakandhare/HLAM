const nodemailer = require('nodemailer');

// Create reusable transporter using SMTP
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
});

// ─────────────────────────────────────────────────────────────────
// 1. COMPANY ADMIN WELCOME EMAIL
//    Sent when System Admin creates a new company + its admin account.
// ─────────────────────────────────────────────────────────────────
const sendCompanyAdminWelcomeEmail = async ({
    adminName,
    adminEmail,
    adminPassword,
    companyName,
    companyAddress,
    checkInTime,
    checkOutTime,
}) => {
    const displayAddress = companyAddress || 'Not configured yet';
    const displayCheckIn = checkInTime || 'Not configured yet';
    const displayCheckOut = checkOutTime || 'Not configured yet';

    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Company Registration – HLAM</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#f0f4ff;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;margin:24px auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 12px 32px -4px rgba(30,58,138,0.12);border:1px solid #c7d2fe;">

            <!-- Header -->
            <tr>
                <td style="background:linear-gradient(135deg,#1e3a8a 0%,#4f46e5 60%,#7c3aed 100%);padding:44px 32px;text-align:center;">
                    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#a5b4fc;text-transform:uppercase;letter-spacing:1.5px;">HLAM – Hirelyft Attendance Management</p>
                    <h1 style="color:#ffffff;margin:0;font-size:27px;font-weight:900;letter-spacing:-0.5px;">🏢 Company Successfully Registered!</h1>
                    <p style="color:#c7d2fe;margin:10px 0 0;font-size:14px;font-weight:500;">Your organisation is now live on the HLAM Portal</p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 32px 20px;">
                    <p style="font-size:17px;font-weight:700;color:#0f172a;margin:0;">Hi ${adminName},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.7;margin:12px 0 0;">
                        Congratulations! Your company <strong style="color:#4f46e5;">${companyName}</strong> has been successfully registered on the
                        <strong>HLAM (Hirelyft Attendance Management Portal)</strong>. Your company admin account has also been created and is ready to use.
                    </p>
                </td>
            </tr>

            <!-- Company Details -->
            <tr>
                <td style="padding:0 32px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;border-radius:14px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 16px;color:#1e3a8a;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">🏗️ Company Details</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;width:160px;">Company Name:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${companyName}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Office Address:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayAddress}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Check-In Time:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayCheckIn}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Check-Out Time:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayCheckOut}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Admin Credentials -->
            <tr>
                <td style="padding:0 32px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#eff6ff;border-radius:14px;border:1px solid #bfdbfe;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 14px;color:#2563eb;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">🔐 Your Admin Account Credentials</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#60a5fa;font-weight:600;width:130px;">Login Email:</td>
                                        <td style="padding:7px 0;color:#1e3a8a;font-weight:700;">${adminEmail}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#60a5fa;font-weight:600;">Password:</td>
                                        <td style="padding:7px 0;color:#1e3a8a;font-weight:700;font-family:monospace;font-size:14px;">${adminPassword}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#60a5fa;font-weight:600;">Role:</td>
                                        <td style="padding:7px 0;color:#1e3a8a;font-weight:700;">Company Administrator</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- What you can do -->
            <tr>
                <td style="padding:4px 32px 22px;">
                    <h3 style="margin:0 0 18px;color:#0f172a;font-size:15px;font-weight:800;">✨ What You Can Do as Company Admin</h3>

                    <!-- Step 1 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#4f46e5);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">1</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Access the Web Dashboard</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Log in to the HLAM Web Dashboard using your credentials above. This is your central hub for managing everything related to your company.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 2 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#4f46e5);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">2</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Register Employees, Managers &amp; Team Leaders</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Go to <strong>Users → Add Employee</strong> to create accounts for your staff. They will automatically receive a welcome email with their login credentials.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 3 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#4f46e5);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">3</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Create Teams &amp; Assign Members</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Navigate to <strong>Teams → Create Team</strong>, assign a Manager and a Team Leader, then add employees as members. A manager or team leader can also be a member of another team.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 4 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#4f46e5);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">4</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Configure Company Settings</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Under <strong>Settings</strong>, set your office location (geofence), official check-in / check-out times, holiday calendar, and leave policies.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 5 -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#4f46e5);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">5</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Monitor Attendance &amp; Approve Leaves</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Track real-time attendance, view detailed reports, approve or reject leave requests, and export CSV reports directly from the dashboard.</p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Security Alert -->
            <tr>
                <td style="padding:0 32px 22px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fef3c7;border-radius:12px;border:1px solid #fde68a;">
                        <tr>
                            <td style="padding:14px 18px;">
                                <p style="margin:0;font-size:12px;color:#d97706;line-height:1.6;font-weight:500;">
                                    <strong>🛡️ Security Advice:</strong> Please change your temporary password immediately after your first login via <strong>Profile → Change Password</strong>. Keep your credentials confidential.
                                </p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background:#f8fafc;padding:24px 32px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:600;">HLAM – Hirelyft Attendance Management Portal</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">This is an automated notification. Please do not reply directly to this email.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: adminEmail,
        subject: `Your company ${companyName} has been successfully registered on HLAM`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Company admin welcome email sent to ${adminEmail}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send company admin welcome email to ${adminEmail}:`, error.message);
        return { success: false, error: error.message };
    }
};

// ─────────────────────────────────────────────────────────────────
// 2. EMPLOYEE / MANAGER / TEAM LEADER WELCOME EMAIL
//    Sent when any user account is created under a company.
// ─────────────────────────────────────────────────────────────────
const sendWelcomeEmail = async ({
    name,
    email,
    password,
    employeeId,
    companyName,
    workMode,
    workType,
    department,
    teamName,
    managerName,
    teamLeaderName,
    role,
}) => {
    const displayWorkMode = workMode || 'Work From Office';
    const displayWorkType = workType || '—';
    const displayCompany = companyName || 'Your Company';

    // Role label for display
    const roleLabels = {
        manager: 'Manager',
        team_leader: 'Team Leader',
        employee: 'Employee',
        company_admin: 'Company Administrator',
    };
    const roleLabel = roleLabels[role] || 'Employee';

    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Your HLAM Account is Ready</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#f0f4ff;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;margin:24px auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 12px 32px -4px rgba(30,58,138,0.12);border:1px solid #c7d2fe;">

            <!-- Header -->
            <tr>
                <td style="background:linear-gradient(135deg,#1e3a8a 0%,#2563eb 60%,#0ea5e9 100%);padding:44px 32px;text-align:center;">
                    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#bfdbfe;text-transform:uppercase;letter-spacing:1.5px;">HLAM – Attendance Management</p>
                    <h1 style="color:#ffffff;margin:0;font-size:27px;font-weight:900;letter-spacing:-0.5px;">🎉 Welcome to the Team!</h1>
                    <p style="color:#bfdbfe;margin:10px 0 0;font-size:14px;font-weight:500;">Your HLAM account has been successfully created for <strong style="color:#fff;">${displayCompany}</strong></p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 32px 20px;">
                    <p style="font-size:17px;font-weight:700;color:#0f172a;margin:0;">Hi ${name},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.7;margin:12px 0 0;">
                        Your <strong>HLAM (Attendance Management)</strong> account has been successfully created for
                        <strong style="color:#2563eb;">${displayCompany}</strong>. You can now mark your daily attendance, track your working hours, and manage leave requests through our mobile application.
                    </p>
                </td>
            </tr>

            <!-- Employment Details -->
            <tr>
                <td style="padding:0 32px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;border-radius:14px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 16px;color:#1e3a8a;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">📋 Your Employment Details</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;width:150px;">Company:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayCompany}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Your Role:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${roleLabel}</td>
                                    </tr>
                                    ${employeeId ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Employee ID:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${employeeId}</td>
                                    </tr>` : ''}
                                    ${!(department && workType && department.toLowerCase() === 'marketing' && workType.toLowerCase() === 'field work') ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Work Mode:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayWorkMode}</td>
                                    </tr>` : ''}
                                    ${workType ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Work Type:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayWorkType}</td>
                                    </tr>` : ''}
                                    ${teamName ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Assigned Team:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${teamName}</td>
                                    </tr>` : ''}
                                    ${managerName ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Team Manager:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${managerName}</td>
                                    </tr>` : ''}
                                    ${teamLeaderName ? `
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Team Leader:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${teamLeaderName}</td>
                                    </tr>` : ''}
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Credentials -->
            <tr>
                <td style="padding:0 32px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#eff6ff;border-radius:14px;border:1px solid #bfdbfe;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 14px;color:#2563eb;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">🔐 Your Login Credentials</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#60a5fa;font-weight:600;width:130px;">Email / Username:</td>
                                        <td style="padding:7px 0;color:#1e3a8a;font-weight:700;">${email}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#60a5fa;font-weight:600;">Password:</td>
                                        <td style="padding:7px 0;color:#1e3a8a;font-weight:700;font-family:monospace;font-size:14px;">${password}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- How to use -->
            <tr>
                <td style="padding:4px 32px 22px;">
                    <h3 style="margin:0 0 18px;color:#0f172a;font-size:15px;font-weight:800;">🚀 How to Get Started</h3>

                    <!-- Step 1 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#2563eb);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">1</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Download &amp; Sign In to the App</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Download the <strong>HLAM Mobile App</strong> on your device and sign in using your email and password listed above.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 2 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#2563eb);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">2</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Mark Your Daily Attendance</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Tap <strong>Check In</strong> at the start of your workday and <strong>Check Out</strong> when done. The app verifies your location against your company's geofence and sets automatic reminders.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 3 -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:16px;">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#2563eb);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">3</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">View Your Attendance History</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Review your complete attendance log, working hours, and daily status (Present / Late / Half-Day / Absent) via the <strong>Dashboard</strong> screen.</p>
                            </td>
                        </tr>
                    </table>

                    <!-- Step 4 -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                            <td style="vertical-align:top;width:34px;">
                                <div style="width:28px;height:28px;background:linear-gradient(135deg,#1e3a8a,#2563eb);border-radius:50%;text-align:center;line-height:28px;color:#fff;font-weight:800;font-size:12px;">4</div>
                            </td>
                            <td style="padding-left:12px;">
                                <h4 style="margin:0 0 4px;font-weight:700;color:#0f172a;font-size:13px;">Apply for Leave</h4>
                                <p style="margin:0;color:#475569;font-size:12px;line-height:1.6;">Submit leave requests directly from the <strong>Leaves</strong> section. You can track the approval status in real-time and receive email notifications on updates.</p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Security Alert -->
            <tr>
                <td style="padding:0 32px 22px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fef3c7;border-radius:12px;border:1px solid #fde68a;">
                        <tr>
                            <td style="padding:14px 18px;">
                                <p style="margin:0;font-size:12px;color:#d97706;line-height:1.6;font-weight:500;">
                                    <strong>🛡️ Security Advice:</strong> Change your temporary password immediately after your first login. Go to <strong>Profile → Change Password</strong> in the app.
                                </p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background:#f8fafc;padding:24px 32px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:600;">HLAM – Hirelyft Attendance Management</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">This is an automated notification. Please do not reply directly to this email.</p>
                    <p style="margin:6px 0 0;font-size:11px;color:#94a3b8;">For assistance, contact your Company Admin or HR department.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: email,
        subject: `Your HLAM (Attendance Management) Account has been successfully created for ${displayCompany}`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Welcome email sent to ${email}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send welcome email to ${email}:`, error.message);
        return { success: false, error: error.message };
    }
};

// ─────────────────────────────────────────────────────────────────
// 3. LEAVE STATUS UPDATE EMAIL
//    Sent when a leave request is approved or rejected.
// ─────────────────────────────────────────────────────────────────
const sendLeaveStatusEmail = async ({
    applicantName,
    applicantEmail,
    status, // 'approved' or 'rejected'
    startDate,
    endDate,
    reason,
    approverName,
    adminComment,
}) => {
    const isApproved = status.toLowerCase() === 'approved';
    const primaryColor = isApproved ? '#10b981' : '#f43f5e';
    const secondaryColor = isApproved ? '#ecfdf5' : '#fff1f2';
    const borderAccent = isApproved ? '#a7f3d0' : '#fecdd3';
    const statusText = isApproved ? 'APPROVED' : 'REJECTED';
    const statusEmoji = isApproved ? '✅' : '❌';

    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Leave Request Update</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#f8fafc;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;margin:20px auto;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 10px 25px -5px rgba(0,0,0,0.05),0 8px 10px -6px rgba(0,0,0,0.05);border:1px solid #e2e8f0;">
            <!-- Header Banner -->
            <tr>
                <td style="background:linear-gradient(135deg,${primaryColor} 0%,#1e293b 120%);padding:40px 30px;text-align:center;">
                    <h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:800;letter-spacing:-0.5px;">Leave Application Status ${statusEmoji}</h1>
                    <p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:14px;font-weight:500;">HLAM – Attendance &amp; Leave Management</p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 30px 20px;">
                    <p style="font-size:16px;font-weight:700;color:#0f172a;margin:0;">Hi ${applicantName},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.6;margin:12px 0 0;">
                        Your leave application has been reviewed by the administration. Here are the review status details:
                    </p>
                </td>
            </tr>

            <!-- Status Indicator -->
            <tr>
                <td style="padding:0 30px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:${secondaryColor};border-radius:12px;border:1px solid ${borderAccent};">
                        <tr>
                            <td style="padding:20px;text-align:center;">
                                <span style="font-size:11px;font-weight:800;color:${primaryColor};text-transform:uppercase;letter-spacing:1px;">Review Decision</span>
                                <h2 style="margin:6px 0 0;color:${primaryColor};font-size:28px;font-weight:900;letter-spacing:-0.5px;">${statusText}</h2>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Leave Details -->
            <tr>
                <td style="padding:0 30px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;border-radius:12px;border:1px solid #e2e8f0;font-size:13px;">
                        <tr>
                            <td style="padding:20px;">
                                <h3 style="margin:0 0 14px;color:#0f172a;font-size:14px;font-weight:800;text-transform:uppercase;letter-spacing:0.5px;">📅 Leave Details</h3>
                                <table width="100%" cellpadding="0" cellspacing="0">
                                    <tr>
                                        <td style="padding:6px 0;color:#64748b;font-weight:600;width:120px;">Start Date:</td>
                                        <td style="padding:6px 0;color:#0f172a;font-weight:700;">${startDate}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:6px 0;color:#64748b;font-weight:600;">End Date:</td>
                                        <td style="padding:6px 0;color:#0f172a;font-weight:700;">${endDate}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:6px 0;color:#64748b;font-weight:600;vertical-align:top;">My Reason:</td>
                                        <td style="padding:6px 0;color:#475569;font-weight:500;line-height:1.4;">${reason}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:6px 0;color:#64748b;font-weight:600;">Reviewed By:</td>
                                        <td style="padding:6px 0;color:#0f172a;font-weight:700;">${approverName}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            ${adminComment ? `
            <!-- Approver Comments -->
            <tr>
                <td style="padding:0 30px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:12px;border:1px solid #e2e8f0;font-style:italic;">
                        <tr>
                            <td style="padding:16px 20px;">
                                <p style="margin:0 0 6px;font-size:11px;color:#64748b;font-weight:800;font-style:normal;text-transform:uppercase;">Approver's Notes:</p>
                                <p style="margin:0;font-size:13px;color:#334155;line-height:1.5;">"${adminComment}"</p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>` : ''}

            <!-- Info -->
            <tr>
                <td style="padding:10px 30px 30px;">
                    <p style="margin:0;font-size:13px;color:#64748b;line-height:1.5;">
                        You can view all leave logs, histories, and balances directly inside the <strong>HLAM Mobile Application</strong>. If you need any clarification, please contact your manager or the HR department.
                    </p>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background-color:#f8fafc;padding:24px 30px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:500;">This is an automated notification from HLAM – Hirelyft Attendance Management.</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">Please do not reply directly to this email.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: applicantEmail,
        subject: `Leave Application Update – [${statusText}]`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Leave status email sent to ${applicantEmail}. Decision: ${statusText}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send leave status email to ${applicantEmail}:`, error.message);
        return { success: false, error: error.message };
    }
};

// ─────────────────────────────────────────────────────────────────
// 4. OTP VERIFICATION EMAIL
//    Sent when any user requests a password reset OTP.
// ─────────────────────────────────────────────────────────────────
const sendOtpEmail = async ({ email, name, otp }) => {
    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Password Reset OTP</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#f8fafc;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:550px;margin:30px auto;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 10px 25px -5px rgba(0,0,0,0.05),0 8px 10px -6px rgba(0,0,0,0.05);border:1px solid #e2e8f0;">
            
            <!-- Header Banner -->
            <tr>
                <td style="background:linear-gradient(135deg,#2563eb 0%,#1e3a8a 120%);padding:36px 30px;text-align:center;">
                    <h1 style="color:#ffffff;margin:0;font-size:22px;font-weight:800;letter-spacing:-0.5px;">Security Verification 🔒</h1>
                    <p style="color:rgba(255,255,255,0.85);margin:6px 0 0;font-size:13px;font-weight:500;">HLAM – Attendance &amp; Employee Management</p>
                </td>
            </tr>

            <!-- Content -->
            <tr>
                <td style="padding:30px 30px 20px;">
                    <p style="font-size:16px;font-weight:700;color:#0f172a;margin:0;">Hi ${name},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.6;margin:12px 0 24px;">
                        A request has been made to reset the password for your HLAM account. Please use the following One-Time Password (OTP) to complete your verification:
                    </p>
                    
                    <!-- OTP Code Container -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:12px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:24px;text-align:center;">
                                <span style="font-size:11px;font-weight:800;color:#64748b;text-transform:uppercase;letter-spacing:1.5px;">Verification Code</span>
                                <h2 style="margin:8px 0 0;color:#2563eb;font-size:36px;font-weight:900;letter-spacing:6px;font-family:monospace;">${otp}</h2>
                            </td>
                        </tr>
                    </table>

                    <p style="font-size:13px;color:#ef4444;line-height:1.6;margin:24px 0 0;font-weight:600;">
                        ⏳ This OTP is valid for 10 minutes only. Do not share this code with anyone.
                    </p>
                </td>
            </tr>

            <!-- Security Alert -->
            <tr>
                <td style="padding:0 30px 24px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid #f1f5f9;padding-top:18px;">
                        <tr>
                            <td>
                                <p style="margin:0;font-size:12px;color:#94a3b8;line-height:1.5;">
                                    If you did not request a password reset, you can safely ignore this email. Your password will remain unchanged.
                                </p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background-color:#f8fafc;padding:20px 30px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0;font-size:11px;color:#94a3b8;font-weight:500;">HLAM – Hirelyft Attendance Management.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: email,
        subject: 'Reset Password Verification Code – HLAM',
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] OTP email successfully sent to ${email}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send OTP email to ${email}:`, error.message);
        return { success: false, error: error.message };
    }
};

const sendCompanyApprovalEmail = async ({ adminName, adminEmail, companyName, createdDate }) => {
    const displayDate = createdDate ? new Date(createdDate).toLocaleDateString() : new Date().toLocaleDateString();

    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Company Approved – HLAM</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#f0f4ff;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;margin:24px auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 12px 32px -4px rgba(30,58,138,0.12);border:1px solid #c7d2fe;">

            <!-- Header -->
            <tr>
                <td style="background:linear-gradient(135deg,#1e3a8a 0%,#10b981 60%,#059669 100%);padding:44px 32px;text-align:center;">
                    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#a7f3d0;text-transform:uppercase;letter-spacing:1.5px;">HLAM – Hirelyft Attendance Management</p>
                    <h1 style="color:#ffffff;margin:0;font-size:26px;font-weight:900;letter-spacing:-0.5px;">🏢 Company Registration Approved!</h1>
                    <p style="color:#a7f3d0;margin:10px 0 0;font-size:14px;font-weight:500;">Company Has Been Successfully Registered on HLAM</p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 32px 20px;">
                    <p style="font-size:17px;font-weight:700;color:#0f172a;margin:0;">Hi ${adminName},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.7;margin:12px 0 0;">
                        We are pleased to inform you that your company registration request has been reviewed and approved by the system administrator.
                        Your company account is now fully active, and you can begin managing your teams, employees, holidays, and settings.
                    </p>
                </td>
            </tr>

            <!-- Registration Details -->
            <tr>
                <td style="padding:0 32px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;border-radius:14px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 16px;color:#1e3a8a;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">📋 Registration Details</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;width:160px;">Company Name:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${companyName}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Admin Full Name:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${adminName}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Admin Email:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${adminEmail}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Registration Date:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayDate}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Action -->
            <tr>
                <td style="padding:0 32px 30px;text-align:center;">
                    <p style="font-size:14px;color:#475569;margin:0 0 16px;">You can now log in to the HLAM mobile application using your registered email and password.</p>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background:#f8fafc;padding:24px 32px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:600;">HLAM – Hirelyft Attendance Management Portal</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">This is an automated notification. Please do not reply directly to this email.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: adminEmail,
        subject: `Company Has Been Successfully Registered on HLAM`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Company approval email sent to ${adminEmail}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send company approval email to ${adminEmail}:`, error.message);
        return { success: false, error: error.message };
    }
};

const sendCompanyRejectionEmail = async ({ adminName, adminEmail, companyName, rejectionReason, createdDate }) => {
    const displayDate = createdDate ? new Date(createdDate).toLocaleDateString() : new Date().toLocaleDateString();

    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Company Registration Rejected – HLAM</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#fcfcfc;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;margin:24px auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 12px 32px -4px rgba(0,0,0,0.1);border:1px solid #fecdd3;">

            <!-- Header -->
            <tr>
                <td style="background:linear-gradient(135deg,#e11d48 0%,#be123c 60%,#9f1239 100%);padding:44px 32px;text-align:center;">
                    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#fecdd3;text-transform:uppercase;letter-spacing:1.5px;">HLAM – Hirelyft Attendance Management</p>
                    <h1 style="color:#ffffff;margin:0;font-size:25px;font-weight:900;letter-spacing:-0.5px;">❌ Registration Request Rejected</h1>
                    <p style="color:#fecdd3;margin:10px 0 0;font-size:14px;font-weight:500;">Unfortunately, we are unable to register your company</p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 32px 20px;">
                    <p style="font-size:17px;font-weight:700;color:#0f172a;margin:0;">Hi ${adminName},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.7;margin:12px 0 0;">
                        Unfortunately, we are unable to register your company <strong style="color:#be123c;">${companyName}</strong> on the HLAM portal at this time.
                        Below is the reason specified by the administrator:
                    </p>
                </td>
            </tr>

            <!-- Rejection Reason -->
            <tr>
                <td style="padding:0 32px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fff5f5;border-radius:12px;border:1px solid #fee2e2;">
                        <tr>
                            <td style="padding:18px 22px;">
                                <p style="margin:0 0 4px;font-size:11px;color:#e11d48;font-weight:800;text-transform:uppercase;">Reason for Rejection:</p>
                                <p style="margin:0;font-size:14px;color:#9f1239;font-weight:600;line-height:1.5;">"${rejectionReason}"</p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Registration Details -->
            <tr>
                <td style="padding:0 32px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;border-radius:14px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 16px;color:#1e3a8a;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">📋 Registration Details Submitted</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;width:160px;">Company Name:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${companyName}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Admin Full Name:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${adminName}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Admin Email:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${adminEmail}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">Submission Date:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${displayDate}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Action -->
            <tr>
                <td style="padding:0 32px 30px;text-align:center;">
                    <p style="font-size:14px;color:#475569;margin:0;">
                        If you wish to register again with corrected details, you may do so through the <strong>Register New Company</strong> form on the login screen.
                    </p>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background:#f8fafc;padding:24px 32px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:600;">HLAM – Hirelyft Attendance Management Portal</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">This is an automated notification. Please do not reply directly to this email.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: adminEmail,
        subject: `Unfortunately, we are unable to register your company`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Company rejection email sent to ${adminEmail}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send company rejection email to ${adminEmail}:`, error.message);
        return { success: false, error: error.message };
    }
};

const sendPasswordResetSuccessEmail = async ({ name, email, newPassword }) => {
    const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Password Reset Completed – HLAM</title>
    </head>
    <body style="margin:0;padding:0;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;background-color:#fcfcfc;color:#1e293b;">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:620px;margin:24px auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 12px 32px -4px rgba(0,0,0,0.1);border:1px solid #e2e8f0;">

            <!-- Header -->
            <tr>
                <td style="background:linear-gradient(135deg,#2563eb 0%,#1d4ed8 60%,#1e3a8a 100%);padding:44px 32px;text-align:center;">
                    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#93c5fd;text-transform:uppercase;letter-spacing:1.5px;">HLAM – Hirelyft Attendance Management</p>
                    <h1 style="color:#ffffff;margin:0;font-size:25px;font-weight:900;letter-spacing:-0.5px;">🔒 Password Changed Successfully</h1>
                    <p style="color:#93c5fd;margin:10px 0 0;font-size:14px;font-weight:500;">Your account password has been updated</p>
                </td>
            </tr>

            <!-- Greeting -->
            <tr>
                <td style="padding:30px 32px 20px;">
                    <p style="font-size:17px;font-weight:700;color:#0f172a;margin:0;">Hi ${name},</p>
                    <p style="font-size:14px;color:#475569;line-height:1.7;margin:12px 0 0;">
                        This email confirms that you have successfully changed your password for your HLAM account. 
                        Below are your credentials to log in:
                    </p>
                </td>
            </tr>

            <!-- Credentials Box -->
            <tr>
                <td style="padding:0 32px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;border-radius:14px;border:1px solid #e2e8f0;">
                        <tr>
                            <td style="padding:22px;">
                                <h3 style="margin:0 0 16px;color:#1e3a8a;font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:0.8px;">🔑 Login Credentials</h3>
                                <table width="100%" cellpadding="0" cellspacing="0" style="font-size:13px;">
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;width:120px;">Email:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;">${email}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding:7px 0;color:#64748b;font-weight:600;">New Password:</td>
                                        <td style="padding:7px 0;color:#0f172a;font-weight:700;font-family:monospace;font-size:14px;letter-spacing:1px;">${newPassword}</td>
                                    </tr>
                                </table>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Caution Notice -->
            <tr>
                <td style="padding:0 32px 30px;">
                    <table width="100%" cellpadding="0" cellspacing="0" style="background:#fffbeb;border-radius:12px;border:1px solid #fef3c7;">
                        <tr>
                            <td style="padding:16px 20px;">
                                <p style="margin:0;font-size:13px;color:#b45309;font-weight:500;line-height:1.5;">
                                    ⚠️ <strong>Security Advisory:</strong> If you did not request this password change, please contact your HLAM administrator or support team immediately to secure your account.
                                </p>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>

            <!-- Footer -->
            <tr>
                <td style="background:#f8fafc;padding:24px 32px;text-align:center;border-top:1px solid #e2e8f0;">
                    <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;font-weight:600;">HLAM – Hirelyft Attendance Management Portal</p>
                    <p style="margin:0;font-size:11px;color:#94a3b8;">This is an automated security notification. Please do not reply directly to this email.</p>
                </td>
            </tr>
        </table>
    </body>
    </html>
    `;

    const mailOptions = {
        from: '"HLAM – Hirelyft Attendance Management" <atharva.kandhare@hirelyft.in>',
        to: email,
        subject: `Your HLAM Account Password Has Been Reset Successfully`,
        html: htmlContent,
    };

    try {
        const info = await transporter.sendMail(mailOptions);
        console.log(`[Mail Service] Password reset confirmation email sent to ${email}. MessageId: ${info.messageId}`);
        return { success: true, messageId: info.messageId };
    } catch (error) {
        console.error(`[Mail Service] Failed to send password reset confirmation email to ${email}:`, error.message);
        return { success: false, error: error.message };
    }
};

module.exports = {
    sendCompanyAdminWelcomeEmail,
    sendWelcomeEmail,
    sendLeaveStatusEmail,
    sendOtpEmail,
    sendCompanyApprovalEmail,
    sendCompanyRejectionEmail,
    sendPasswordResetSuccessEmail,
};

