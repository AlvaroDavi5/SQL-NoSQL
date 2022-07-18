
SELECT
  U.id as userId,
  U.email,
  U.token,
  UA.roleId,
  R.name AS roleName,
  R.createdAt
FROM Users U
INNER JOIN UserAccess UA
ON UA.userId = U.id AND U.token = "7b790a74-c47e-431b-b8b0-36b1f0b096c4"
INNER JOIN Roles R
ON R.id = UA.roleId AND R.name = "ADMIN";


SELECT * FROM UserAccess UA WHERE merchantId IN (1, 2, 3, 4) OR economicGroupId IS NOT NULL;

