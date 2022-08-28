
SELECT * FROM UserAccess UA WHERE merchantId IN (1, 2, 3, 4) OR economicGroupId IS NOT NULL;


SELECT
  M.id as merchantId,
  M.name as merchantName,
  B.id as brandId,
  B.name AS brandName,
  EG.id as EconomicGroupId,
  EG.name AS EconomicGroupName
FROM Merchants M
INNER JOIN Brands B
ON B.id = M.brandId AND B.id = 7
INNER JOIN EconomicGroups EG
ON EG.id = B.economicGroupId AND EG.id = 4;

