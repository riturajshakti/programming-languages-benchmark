const fs = require("fs");

const N = 10_000_000; // Number of data rows
const OUTPUT_FILE = "users.csv";

const records = [
  ["1", "Alice", "alice@example.com", "USA", "25", "Engineer", "75000"],
  ["2", "Bob", "bob@example.com", "Canada", "31", "Designer", "68000"],
  ["3", "Charlie", "charlie@example.com", "UK", "29", "Teacher", "52000"],
  ["4", "David", "david@example.com", "Germany", "35", "Developer", "92000"],
  ["5", "Eva", "eva@example.com", "France", "27", "Doctor", "110000"],
  ["6", "Frank", "frank@example.com", "Australia", "42", "Manager", "98000"],
  ["7", "Grace", "grace@example.com", "India", "24", "Student", "12000"],
  ["8", "Henry", "henry@example.com", "Japan", "38", "Architect", "105000"],
  ["9", "Ivy", "ivy@example.com", "Brazil", "30", "Analyst", "64000"],
  ["10", "Jack", "jack@example.com", "Singapore", "33", "Consultant", "88000"],
];

const stream = fs.createWriteStream(OUTPUT_FILE);

stream.write("id,name,email,country,age,profession,salary\n");

const BAR_WIDTH = 40;
const start = Date.now();

let written = 0;
let lastUpdate = 0;

function renderProgress() {
  const now = Date.now();

  // Update at most every 100ms
  if (now - lastUpdate < 100 && written !== N) return;
  lastUpdate = now;

  const percent = written / N;
  const filled = Math.floor(percent * BAR_WIDTH);

  const bar =
    "█".repeat(filled) + "░".repeat(BAR_WIDTH - filled);

  const elapsed = (now - start) / 1000;
  const speed = Math.floor(written / Math.max(elapsed, 1));

  process.stdout.write(
    `\r[${bar}] ${(percent * 100).toFixed(2)}% | ${written.toLocaleString()}/${N.toLocaleString()} rows | ${speed.toLocaleString()} rows/s`
  );
}

function write() {
  let ok = true;

  while (written < N && ok) {
    const row = records[Math.floor(Math.random() * records.length)];
    ok = stream.write(row.join(",") + "\n");
    written++;
    renderProgress();
  }

  if (written < N) {
    stream.once("drain", write);
  } else {
    stream.end();
  }
}

function humanFileSize(bytes) {
  const units = ["B", "KB", "MB", "GB", "TB"];

  let i = 0;
  let size = bytes;

  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }

  return `${size.toFixed(2)} ${units[i]}`;
}

stream.on("finish", () => {
  renderProgress();

  const elapsed = (Date.now() - start) / 1000;
  const stats = fs.statSync(OUTPUT_FILE);

  console.log(`

Done!
File      : ${OUTPUT_FILE}
Rows      : ${N.toLocaleString()}
Size      : ${humanFileSize(stats.size)} (${stats.size.toLocaleString()} bytes)
Time      : ${elapsed.toFixed(2)}s
Avg Speed : ${Math.floor(N / elapsed).toLocaleString()} rows/s`);
});

write();

