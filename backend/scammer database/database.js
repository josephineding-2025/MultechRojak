const reports = [
  {
    id: 1,
    suspectName: "Fake Tech Support",
    contact: "+1-202-555-0147",
    scamType: "tech-support",
    description: "Pretended to be a laptop security provider and demanded payment in gift cards.",
    riskScore: 88,
    location: "Manila",
    scriptPattern: "urgent remote access request",
    reportedAt: "2026-03-15T00:00:00.000Z",
  },
  {
    id: 2,
    suspectName: "Prize Claim Team",
    contact: "winner@claim-fast.example",
    scamType: "phishing",
    description: "Requested bank credentials to release a fake cash prize.",
    riskScore: 81,
    location: "Jakarta",
    scriptPattern: "fake prize claim",
    reportedAt: "2026-03-14T00:00:00.000Z",
  },
  {
    id: 3,
    suspectName: "Promo Center",
    contact: "+66-555-0110",
    scamType: "phishing",
    description: "Claimed a cash reward was pending and asked for a processing fee.",
    riskScore: 77,
    location: "Bangkok",
    scriptPattern: "fake prize claim",
    reportedAt: "2026-03-13T00:00:00.000Z",
  },
];

let nextId = reports.length + 1;

function normalizeText(value) {
  return String(value || "").trim();
}

function getAllReports(filters = {}) {
  const query = normalizeText(filters.query).toLowerCase();
  const scamType = normalizeText(filters.scamType).toLowerCase();
  const minRiskScore = Number.isFinite(Number(filters.minRiskScore))
    ? Number(filters.minRiskScore)
    : null;

  return reports.filter((report) => {
    const matchesQuery =
      !query ||
      report.suspectName.toLowerCase().includes(query) ||
      report.contact.toLowerCase().includes(query) ||
      report.description.toLowerCase().includes(query);

    const matchesType = !scamType || report.scamType.toLowerCase() === scamType;
    const matchesRisk = minRiskScore === null || report.riskScore >= minRiskScore;

    return matchesQuery && matchesType && matchesRisk;
  });
}

function getReportById(id) {
  return reports.find((report) => report.id === Number(id)) || null;
}

function createReport(payload) {
  const normalizedScriptPattern = normalizeText(payload.scriptPattern);
  const report = {
    id: nextId,
    suspectName: normalizeText(payload.suspectName),
    contact: normalizeText(payload.contact),
    scamType: normalizeText(payload.scamType).toLowerCase(),
    description: normalizeText(payload.description),
    riskScore: Number(payload.riskScore),
    location: normalizeText(payload.location),
    scriptPattern: normalizedScriptPattern,
    reportedAt: new Date().toISOString(),
  };

  reports.unshift(report);
  nextId += 1;

  return report;
}

function hasMatchingScriptPattern(scriptPattern) {
  const normalizedScriptPattern = normalizeText(scriptPattern).toLowerCase();

  return reports.some(
    (report) => normalizeText(report.scriptPattern).toLowerCase() === normalizedScriptPattern
  );
}

function getSummary() {
  const totalReports = reports.length;
  const scriptPatternMap = reports.reduce((accumulator, report) => {
    const pattern = normalizeText(report.scriptPattern);
    const location = normalizeText(report.location);

    if (!pattern) {
      return accumulator;
    }

    if (!accumulator[pattern]) {
      accumulator[pattern] = new Set();
    }

    if (location) {
      accumulator[pattern].add(location);
    }

    return accumulator;
  }, {});

  const allScamScripts = Object.entries(scriptPatternMap)
    .map(([pattern, regions]) => ({
      pattern,
      regions: Array.from(regions).sort(),
    }))
    .sort((left, right) => {
      if (right.regions.length !== left.regions.length) {
        return right.regions.length - left.regions.length;
      }

      return left.pattern.localeCompare(right.pattern);
    });

  const topScamScripts = allScamScripts.filter((entry) => entry.regions.length > 1);

  const regionsAffected = Array.from(
    new Set(
      reports
        .map((report) => normalizeText(report.location))
        .filter(Boolean)
    )
  ).sort();

  return {
    totalReports,
    topScamScripts,
    regionsAffected,
  };
}

module.exports = {
  createReport,
  getAllReports,
  getReportById,
  getSummary,
  hasMatchingScriptPattern,
};
