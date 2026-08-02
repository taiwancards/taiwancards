import { Controller } from "@hotwired/stimulus";

const DAY_PREFIXES = ["初", "十", "廿", "卅"];
const DAY_DIGITS = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"];
const MONTH_NAMES = [
  "正",
  "二",
  "三",
  "四",
  "五",
  "六",
  "七",
  "八",
  "九",
  "十",
  "十一",
  "十二",
];

function dayLabel(day) {
  if (day === 10) return "初十";
  if (day === 20) return "二十";
  if (day === 30) return "三十";
  return DAY_PREFIXES[Math.floor((day - 1) / 10)] + DAY_DIGITS[(day - 1) % 10];
}

function monthLabel(month, leap) {
  return (leap ? "閏" : "") + MONTH_NAMES[month - 1] + "月";
}

function parseDate(value) {
  const parts = value.split("-").map((n) => parseInt(n, 10));
  if (parts.length !== 3 || parts.some(Number.isNaN)) return null;
  return Date.UTC(parts[0], parts[1] - 1, parts[2]);
}

function formatDate(stamp) {
  const date = new Date(stamp);
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

const DAY_MS = 86400000;

export default class extends Controller {
  static targets = ["year", "month", "day", "gregorianOut", "date", "lunarOut"];
  static values = { table: Array };

  connect() {
    this.index = new Map();
    this.tableValue.forEach((row) => this.index.set(row.y, row));
    this.buildMonths();
    this.toGregorian();
    this.toLunar();
  }

  monthsOf(row) {
    const seq = [];
    for (let n = 1; n <= 12; n += 1) {
      seq.push({ number: n, leap: false });
      if (n === row.l) seq.push({ number: n, leap: true });
    }
    return seq.map((m, i) => ({ ...m, length: row.m[i] }));
  }

  buildMonths() {
    const row = this.index.get(parseInt(this.yearTarget.value, 10));
    if (!row) return;
    const previous = this.monthTarget.value;
    this.monthTarget.innerHTML = "";
    this.monthsOf(row).forEach((m) => {
      const option = document.createElement("option");
      option.value = `${m.number}:${m.leap ? "1" : "0"}`;
      option.textContent = monthLabel(m.number, m.leap);
      this.monthTarget.appendChild(option);
    });
    const match = Array.from(this.monthTarget.options).find(
      (o) => o.value === previous,
    );
    this.monthTarget.value = match ? previous : "1:0";
    this.buildDays();
  }

  buildDays() {
    const row = this.index.get(parseInt(this.yearTarget.value, 10));
    if (!row) return;
    const [number, leap] = this.monthTarget.value.split(":");
    const month = this.monthsOf(row).find(
      (m) => m.number === parseInt(number, 10) && m.leap === (leap === "1"),
    );
    if (!month) return;
    const previous = parseInt(this.dayTarget.value, 10);
    this.dayTarget.innerHTML = "";
    for (let d = 1; d <= month.length; d += 1) {
      const option = document.createElement("option");
      option.value = String(d);
      option.textContent = dayLabel(d);
      this.dayTarget.appendChild(option);
    }
    this.dayTarget.value = String(
      previous >= 1 && previous <= month.length ? previous : 1,
    );
  }

  yearChanged() {
    this.buildMonths();
    this.toGregorian();
  }

  monthChanged() {
    this.buildDays();
    this.toGregorian();
  }

  toGregorian() {
    const row = this.index.get(parseInt(this.yearTarget.value, 10));
    if (!row) return;
    const [number, leap] = this.monthTarget.value.split(":");
    const day = parseInt(this.dayTarget.value, 10);
    const start = parseDate(row.n);
    let offset = 0;
    let found = null;
    this.monthsOf(row).forEach((m) => {
      if (m.number === parseInt(number, 10) && m.leap === (leap === "1"))
        found = offset;
      if (found === null) offset += m.length;
    });
    if (found === null || Number.isNaN(day)) return;
    const stamp = start + (found + day - 1) * DAY_MS;
    const date = new Date(stamp);
    const template = this.gregorianOutTarget.dataset.template || "%{date}";
    this.gregorianOutTarget.textContent = template
      .replace("%{date}", formatDate(stamp))
      .replace(
        "%{weekday}",
        date.toLocaleDateString(document.documentElement.lang || "en", {
          weekday: "long",
          timeZone: "UTC",
        }),
      );
  }

  toLunar() {
    const stamp = parseDate(this.dateTarget.value);
    if (stamp === null) return;
    const rows = this.tableValue;
    let row = null;
    for (let i = rows.length - 1; i >= 0; i -= 1) {
      if (parseDate(rows[i].n) <= stamp) {
        row = rows[i];
        break;
      }
    }
    if (!row) {
      this.lunarOutTarget.textContent =
        this.lunarOutTarget.dataset.outOfRange || "";
      return;
    }
    let offset = Math.round((stamp - parseDate(row.n)) / DAY_MS);
    const months = this.monthsOf(row);
    const total = months.reduce((sum, m) => sum + m.length, 0);
    if (offset >= total) {
      this.lunarOutTarget.textContent =
        this.lunarOutTarget.dataset.outOfRange || "";
      return;
    }
    for (let i = 0; i < months.length; i += 1) {
      if (offset < months[i].length) {
        const template =
          this.lunarOutTarget.dataset.template || "%{month}%{day}";
        this.lunarOutTarget.textContent = template
          .replace("%{year}", String(row.y))
          .replace("%{month}", monthLabel(months[i].number, months[i].leap))
          .replace("%{day}", dayLabel(offset + 1));
        return;
      }
      offset -= months[i].length;
    }
  }
}
