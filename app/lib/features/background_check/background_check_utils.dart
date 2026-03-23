bool isRiskLevelEligibleForCommunity(String riskLevel) {
  switch (riskLevel.toUpperCase()) {
    case 'MEDIUM':
    case 'HIGH':
    case 'CRITICAL':
      return true;
    default:
      return false;
  }
}
