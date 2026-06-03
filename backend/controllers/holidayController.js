const { Holiday, HolidayException, User, Team } = require('../associations');
const { Op } = require('sequelize');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const XLSX = require('xlsx');

// ── Multer for Holiday Sheet Upload ───────────────────────────────────────────
const holidaySheetDir = path.join(__dirname, '../uploads/holidays');
if (!fs.existsSync(holidaySheetDir)) {
  fs.mkdirSync(holidaySheetDir, { recursive: true });
}

const holidayStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, holidaySheetDir),
  filename: (req, file, cb) => {
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `holiday_sheet_${unique}${path.extname(file.originalname)}`);
  },
});

const uploadHolidaySheet = multer({
  storage: holidayStorage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (req, file, cb) => {
    const allowed = ['.csv', '.xlsx', '.xls'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) return cb(null, true);
    cb(new Error('Only CSV and Excel files are allowed for holiday sheets.'));
  },
});

// ── Helper: Parse date column from workbook ───────────────────────────────────
const parseDatesFromWorkbook = (filePath) => {
  const workbook = XLSX.readFile(filePath);
  const results = [];

  for (const sheetName of workbook.SheetNames) {
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });

    for (const row of rows) {
      for (const cell of row) {
        if (!cell) continue;

        // Try to parse as date
        let dateObj = null;
        let name = '';

        if (typeof cell === 'number') {
          // Excel serial date number
          dateObj = XLSX.SSF.parse_date_code(cell);
          if (dateObj) {
            const y = dateObj.y;
            const m = String(dateObj.m).padStart(2, '0');
            const d = String(dateObj.d).padStart(2, '0');
            name = `${y}-${m}-${d}`;
            results.push({ date: name, name: '' });
          }
        } else if (typeof cell === 'string') {
          // Try common date formats
          const trimmed = cell.trim();
          // Match: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, MM/DD/YYYY
          const patterns = [
            { re: /^(\d{4})-(\d{1,2})-(\d{1,2})$/, fn: (m) => `${m[1]}-${String(m[2]).padStart(2,'0')}-${String(m[3]).padStart(2,'0')}` },
            { re: /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/, fn: (m) => `${m[3]}-${String(m[2]).padStart(2,'0')}-${String(m[1]).padStart(2,'0')}` },
            { re: /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2})$/, fn: (m) => `20${m[3]}-${String(m[2]).padStart(2,'0')}-${String(m[1]).padStart(2,'0')}` },
          ];

          for (const p of patterns) {
            const match = trimmed.match(p.re);
            if (match) {
              const isoDate = p.fn(match);
              const testDate = new Date(isoDate);
              if (!isNaN(testDate)) {
                results.push({ date: isoDate, name: '' });
                break;
              }
            }
          }
        }
      }
    }
  }

  // Also look for a name column: if row has two values and second looks like text, treat as name
  // Re-parse looking for { date, name } pairs in rows
  const namedResults = [];
  const seenDates = new Set();
  for (const sheetName of workbook.SheetNames) {
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

    for (const row of rows) {
      const values = Object.values(row).map(v => String(v).trim()).filter(Boolean);
      // Try to find date and name in row
      let foundDate = null;
      let foundName = '';
      for (const val of values) {
        const patterns = [
          /^(\d{4})-(\d{1,2})-(\d{1,2})$/,
          /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/,
        ];
        for (const p of patterns) {
          if (p.test(val)) {
            const parsed = new Date(val.replace(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/, '$3-$2-$1'));
            if (!isNaN(parsed)) {
              foundDate = parsed.toISOString().slice(0, 10);
              break;
            }
          }
        }
        if (!foundDate) {
          // Also try if it's a numeric date
          const num = parseFloat(val);
          if (!isNaN(num) && num > 40000 && num < 60000) {
            const parsed = XLSX.SSF.parse_date_code(num);
            if (parsed) {
              foundDate = `${parsed.y}-${String(parsed.m).padStart(2,'0')}-${String(parsed.d).padStart(2,'0')}`;
            }
          }
        }
      }
      for (const val of values) {
        if (val && !/^\d/.test(val) && val.length > 2) {
          foundName = val;
          break;
        }
      }
      if (foundDate && !seenDates.has(foundDate)) {
        seenDates.add(foundDate);
        namedResults.push({ date: foundDate, name: foundName || 'Company Holiday' });
      }
    }
  }

  // Merge: prefer named results, fallback to results
  if (namedResults.length > 0) return namedResults;

  const unique = [];
  const seen = new Set();
  for (const r of results) {
    if (!seen.has(r.date)) {
      seen.add(r.date);
      unique.push({ date: r.date, name: 'Company Holiday' });
    }
  }
  return unique;
};

// ── Controllers ───────────────────────────────────────────────────────────────

// GET /api/holidays — list holidays for current user's company
const listHolidays = async (req, res) => {
  try {
    const companyId = req.user.companyId;
    if (!companyId) return res.status(403).json({ message: 'No company associated.' });

    const { month, year } = req.query;
    const where = { companyId };

    if (month && year) {
      const start = `${year}-${String(month).padStart(2, '0')}-01`;
      const lastDay = new Date(year, month, 0).getDate();
      const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
      where.date = { [Op.between]: [start, end] };
    } else if (year) {
      where.date = { [Op.between]: [`${year}-01-01`, `${year}-12-31`] };
    }

    const holidays = await Holiday.findAll({
      where,
      include: [{
        model: HolidayException,
        as: 'exceptions',
        include: [
          { model: User, as: 'user', attributes: ['id', 'name', 'email', 'employeeId'], required: false },
          { model: Team, as: 'team', attributes: ['id', 'name'], required: false },
        ],
        required: false,
      }],
      order: [['date', 'ASC']],
    });

    return res.json({ holidays });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch holidays', error: error.message });
  }
};

// POST /api/holidays — create a single holiday
const createHoliday = async (req, res) => {
  try {
    const { date, name } = req.body;
    const companyId = req.user.companyId;
    if (!companyId) return res.status(403).json({ message: 'No company associated.' });
    if (!date) return res.status(400).json({ message: 'Date is required.' });

    const [holiday, created] = await Holiday.findOrCreate({
      where: { companyId, date },
      defaults: { name: name || 'Company Holiday', isActive: true },
    });

    if (!created) {
      // Update name if already exists
      holiday.name = name || holiday.name;
      await holiday.save();
    }

    return res.status(201).json({ message: 'Holiday saved', holiday });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to create holiday', error: error.message });
  }
};

// PUT /api/holidays/:id — update a holiday
const updateHoliday = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, date, isActive } = req.body;
    const companyId = req.user.companyId;

    const holiday = await Holiday.findOne({ where: { id, companyId } });
    if (!holiday) return res.status(404).json({ message: 'Holiday not found.' });

    if (name !== undefined) holiday.name = name;
    if (date !== undefined) holiday.date = date;
    if (isActive !== undefined) holiday.isActive = isActive;
    await holiday.save();

    return res.json({ message: 'Holiday updated', holiday });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update holiday', error: error.message });
  }
};

// DELETE /api/holidays/:id — delete a holiday
const deleteHoliday = async (req, res) => {
  try {
    const { id } = req.params;
    const companyId = req.user.companyId;

    const holiday = await Holiday.findOne({ where: { id, companyId } });
    if (!holiday) return res.status(404).json({ message: 'Holiday not found.' });

    // Delete exceptions first
    await HolidayException.destroy({ where: { holidayId: id } });
    await holiday.destroy();

    return res.json({ message: 'Holiday deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete holiday', error: error.message });
  }
};

// POST /api/holidays/parse-sheet — parse an uploaded CSV/Excel file and return dates
const parseHolidaySheet = [
  (req, res, next) => {
    uploadHolidaySheet.single('sheet')(req, res, (err) => {
      if (err instanceof multer.MulterError) {
        return res.status(400).json({ message: `Upload error: ${err.message}` });
      } else if (err) {
        return res.status(400).json({ message: err.message });
      }
      next();
    });
  },
  async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ message: 'No file uploaded.' });

      const parsed = parseDatesFromWorkbook(req.file.path);

      // Clean up uploaded file after parsing
      fs.unlink(req.file.path, () => {});

      if (parsed.length === 0) {
        return res.status(400).json({ message: 'No valid dates found in the uploaded file. Please check the file format.' });
      }

      return res.json({ parsed, count: parsed.length });
    } catch (error) {
      console.error('[HolidayController] parse-sheet error:', error);
      return res.status(500).json({ message: 'Failed to parse sheet', error: error.message });
    }
  }
];

// POST /api/holidays/bulk — bulk create holidays from parsed list
const bulkCreateHolidays = async (req, res) => {
  try {
    const { holidays } = req.body; // [{ date, name }]
    const companyId = req.user.companyId;
    if (!companyId) return res.status(403).json({ message: 'No company associated.' });
    if (!holidays || !Array.isArray(holidays)) {
      return res.status(400).json({ message: 'holidays array is required.' });
    }

    const results = [];
    for (const h of holidays) {
      if (!h.date) continue;
      const [record, created] = await Holiday.findOrCreate({
        where: { companyId, date: h.date },
        defaults: { name: h.name || 'Company Holiday', isActive: true },
      });
      if (!created && h.name) {
        record.name = h.name;
        await record.save();
      }
      results.push(record);
    }

    return res.status(201).json({ message: `${results.length} holidays saved.`, holidays: results });
  } catch (error) {
    return res.status(500).json({ message: 'Bulk create failed', error: error.message });
  }
};

// GET /api/holidays/:id/exceptions — list exceptions for a holiday
const listExceptions = async (req, res) => {
  try {
    const { id } = req.params;
    const companyId = req.user.companyId;

    const holiday = await Holiday.findOne({ where: { id, companyId } });
    if (!holiday) return res.status(404).json({ message: 'Holiday not found.' });

    const exceptions = await HolidayException.findAll({
      where: { holidayId: id },
      include: [
        { model: User, as: 'user', attributes: ['id', 'name', 'email', 'employeeId'], required: false },
        { model: Team, as: 'team', attributes: ['id', 'name'], required: false },
      ],
    });

    return res.json({ exceptions });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch exceptions', error: error.message });
  }
};

// POST /api/holidays/:id/exceptions — add an exception (team or user)
const addException = async (req, res) => {
  try {
    const { id } = req.params;
    const { teamId, userId, note } = req.body;
    const companyId = req.user.companyId;

    const holiday = await Holiday.findOne({ where: { id, companyId } });
    if (!holiday) return res.status(404).json({ message: 'Holiday not found.' });
    if (!teamId && !userId) {
      return res.status(400).json({ message: 'Either teamId or userId is required.' });
    }

    const exception = await HolidayException.create({
      holidayId: id,
      companyId,
      teamId: teamId || null,
      userId: userId || null,
      note: note || null,
    });

    return res.status(201).json({ message: 'Exception added', exception });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to add exception', error: error.message });
  }
};

// DELETE /api/holidays/:id/exceptions/:eid — remove an exception
const removeException = async (req, res) => {
  try {
    const { id, eid } = req.params;
    const companyId = req.user.companyId;

    const exception = await HolidayException.findOne({
      where: { id: eid, holidayId: id, companyId },
    });
    if (!exception) return res.status(404).json({ message: 'Exception not found.' });

    await exception.destroy();
    return res.json({ message: 'Exception removed' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to remove exception', error: error.message });
  }
};

module.exports = {
  listHolidays,
  createHoliday,
  updateHoliday,
  deleteHoliday,
  parseHolidaySheet,
  bulkCreateHolidays,
  listExceptions,
  addException,
  removeException,
};
