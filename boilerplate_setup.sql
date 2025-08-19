
-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Start transaction for schema creation
BEGIN;

-- Create Users table if not exists
CREATE TABLE IF NOT EXISTS "Users" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "fullName" VARCHAR(100) NOT NULL DEFAULT '',
    "email" VARCHAR(70) NOT NULL DEFAULT '',
    "password" VARCHAR(550) NOT NULL DEFAULT '',
    "phone" VARCHAR(16),
    "docType" VARCHAR(10),
    "document" VARCHAR(18),
    "fu" VARCHAR(2),
    "createdAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    "deletedAt" TIMESTAMP WITHOUT TIME ZONE,
    "deletedBy" VARCHAR(260),

    CONSTRAINT "PK_Users" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_Users_email" UNIQUE ("email")
);

-- Add comments to Users table
COMMENT ON TABLE "Users" IS 'Users data structure';
COMMENT ON COLUMN "Users"."id" IS 'Unique user identifier';
COMMENT ON COLUMN "Users"."fullName" IS 'User full name';
COMMENT ON COLUMN "Users"."email" IS 'User email address (unique)';
COMMENT ON COLUMN "Users"."password" IS 'User encrypted password';
COMMENT ON COLUMN "Users"."phone" IS 'User phone number';
COMMENT ON COLUMN "Users"."docType" IS 'Document type (CPF, RG, etc.)';
COMMENT ON COLUMN "Users"."document" IS 'Document number';
COMMENT ON COLUMN "Users"."fu" IS 'Brazilian Federative Unity (state code)';
COMMENT ON COLUMN "Users"."createdAt" IS 'User creation timestamp';
COMMENT ON COLUMN "Users"."updatedAt" IS 'User last update timestamp';
COMMENT ON COLUMN "Users"."deletedAt" IS 'User soft deletion timestamp';
COMMENT ON COLUMN "Users"."deletedBy" IS 'ID of user who performed deletion';

-- Create UserPreferences table if not exists
CREATE TABLE IF NOT EXISTS "UserPreferences" (
    "id" UUID NOT NULL DEFAULT uuid_generate_v4(),
    "imagePath" VARCHAR(260),
    "defaultTheme" VARCHAR(20),
    "createdAt" TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    "deletedAt" TIMESTAMP WITHOUT TIME ZONE,
    "userId" UUID,

    CONSTRAINT "PK_UserPreferences" PRIMARY KEY ("id"),
    CONSTRAINT "UQ_UserPreferences_userId" UNIQUE ("userId")
);

-- Add comments to UserPreferences table
COMMENT ON TABLE "UserPreferences" IS 'User preferences and settings data structure';
COMMENT ON COLUMN "UserPreferences"."id" IS 'Unique preference record identifier';
COMMENT ON COLUMN "UserPreferences"."imagePath" IS 'User profile image file path';
COMMENT ON COLUMN "UserPreferences"."defaultTheme" IS 'User preferred theme (DEFAULT, DARK, LIGHT, etc.)';
COMMENT ON COLUMN "UserPreferences"."createdAt" IS 'Preference creation timestamp';
COMMENT ON COLUMN "UserPreferences"."updatedAt" IS 'Preference last update timestamp';
COMMENT ON COLUMN "UserPreferences"."deletedAt" IS 'Preference soft deletion timestamp';
COMMENT ON COLUMN "UserPreferences"."userId" IS 'Reference to Users table';

-- Add foreign key constraint
ALTER TABLE "UserPreferences"
    DROP CONSTRAINT IF EXISTS "FK_UserPreferences_userId";

ALTER TABLE "UserPreferences"
    ADD CONSTRAINT "FK_UserPreferences_userId"
    FOREIGN KEY ("userId")
    REFERENCES "Users"("id")
    ON DELETE CASCADE
    ON UPDATE CASCADE;

-- Commit schema creation transaction
COMMIT;

-- Start transaction for indexes creation
BEGIN;

-- Primary indexes (already created with PRIMARY KEY constraints)
-- Users.id and UserPreferences.id are automatically indexed

-- Create indexes for Users table
CREATE INDEX IF NOT EXISTS "IDX_Users_email" ON "Users" ("email");
CREATE INDEX IF NOT EXISTS "IDX_Users_fullName" ON "Users" ("fullName");
CREATE INDEX IF NOT EXISTS "IDX_Users_createdAt" ON "Users" ("createdAt");
CREATE INDEX IF NOT EXISTS "IDX_Users_updatedAt" ON "Users" ("updatedAt");
CREATE INDEX IF NOT EXISTS "IDX_Users_deletedAt" ON "Users" ("deletedAt");
CREATE INDEX IF NOT EXISTS "IDX_Users_phone" ON "Users" ("phone") WHERE "phone" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "IDX_Users_docType_document" ON "Users" ("docType", "document") WHERE "docType" IS NOT NULL AND "document" IS NOT NULL;

-- Partial index for active users (non-deleted)
CREATE INDEX IF NOT EXISTS "IDX_Users_active" ON "Users" ("id", "email", "fullName") WHERE "deletedAt" IS NULL;

-- Composite index for search and filtering
CREATE INDEX IF NOT EXISTS "IDX_Users_search" ON "Users" ("fullName", "email", "createdAt") WHERE "deletedAt" IS NULL;

-- Create indexes for UserPreferences table
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_userId" ON "UserPreferences" ("userId");
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_createdAt" ON "UserPreferences" ("createdAt");
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_updatedAt" ON "UserPreferences" ("updatedAt");
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_deletedAt" ON "UserPreferences" ("deletedAt");
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_defaultTheme" ON "UserPreferences" ("defaultTheme") WHERE "defaultTheme" IS NOT NULL;

-- Partial index for active preferences (non-deleted)
CREATE INDEX IF NOT EXISTS "IDX_UserPreferences_active" ON "UserPreferences" ("userId", "defaultTheme") WHERE "deletedAt" IS NULL;

-- Commit indexes creation transaction
COMMIT;

-- Start transaction for performance optimizations
BEGIN;

-- Create a view for active users with preferences
CREATE OR REPLACE VIEW "ActiveUsersWithPreferences" AS
SELECT
    u."id",
    u."fullName",
    u."email",
    u."phone",
    u."createdAt" as "userCreatedAt",
    u."updatedAt" as "userUpdatedAt",
    up."id" as "preferenceId",
    up."imagePath",
    up."defaultTheme",
    up."createdAt" as "preferenceCreatedAt",
    up."updatedAt" as "preferenceUpdatedAt"
FROM "Users" u
LEFT JOIN "UserPreferences" up ON u."id" = up."userId" AND up."deletedAt" IS NULL
WHERE u."deletedAt" IS NULL;

COMMENT ON VIEW "ActiveUsersWithPreferences" IS 'View combining active users with their preferences for optimized queries';

-- Create function to update timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."updatedAt" = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
DROP TRIGGER IF EXISTS update_users_updated_at ON "Users";
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON "Users"
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON "UserPreferences";
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON "UserPreferences"
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Commit performance optimizations transaction
COMMIT;

-- Start transaction for additional utility functions
BEGIN;

-- Function to soft delete a user and cascade to preferences
CREATE OR REPLACE FUNCTION soft_delete_user(user_id UUID, deleted_by_id VARCHAR(260) DEFAULT NULL)
RETURNS BOOLEAN AS $$
BEGIN
    -- Update user record
    UPDATE "Users"
    SET "deletedAt" = NOW(),
        "deletedBy" = deleted_by_id,
        "updatedAt" = NOW()
    WHERE "id" = user_id AND "deletedAt" IS NULL;

    -- Update user preferences record
    UPDATE "UserPreferences"
    SET "deletedAt" = NOW(),
        "updatedAt" = NOW()
    WHERE "userId" = user_id AND "deletedAt" IS NULL;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to restore a soft-deleted user
CREATE OR REPLACE FUNCTION restore_user(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Restore user record
    UPDATE "Users"
    SET "deletedAt" = NULL,
        "deletedBy" = NULL,
        "updatedAt" = NOW()
    WHERE "id" = user_id AND "deletedAt" IS NOT NULL;

    -- Restore user preferences record
    UPDATE "UserPreferences"
    SET "deletedAt" = NULL,
        "updatedAt" = NOW()
    WHERE "userId" = user_id AND "deletedAt" IS NOT NULL;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_statistics()
RETURNS TABLE(
    total_users BIGINT,
    active_users BIGINT,
    deleted_users BIGINT,
    users_with_preferences BIGINT,
    users_with_themes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM "Users") as total_users,
        (SELECT COUNT(*) FROM "Users" WHERE "deletedAt" IS NULL) as active_users,
        (SELECT COUNT(*) FROM "Users" WHERE "deletedAt" IS NOT NULL) as deleted_users,
        (SELECT COUNT(*) FROM "UserPreferences" WHERE "deletedAt" IS NULL) as users_with_preferences,
        (SELECT COUNT(*) FROM "UserPreferences" WHERE "defaultTheme" IS NOT NULL AND "deletedAt" IS NULL) as users_with_themes;
END;
$$ LANGUAGE plpgsql;

-- Commit utility functions transaction
COMMIT;

-- Start transaction for sample data (optional - can be commented out)
BEGIN;

-- Insert sample users (only if tables are empty)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM "Users" LIMIT 1) THEN
        -- Insert test users
        INSERT INTO "Users" ("id", "fullName", "email", "password", "phone") VALUES
        (uuid_generate_v4(), 'John Doe', 'john.doe@example.com', '$2b$10$hashedpassword1', '+1234567890'),
        (uuid_generate_v4(), 'Jane Smith', 'jane.smith@example.com', '$2b$10$hashedpassword2', '+1234567891'),
        (uuid_generate_v4(), 'Admin User', 'admin@example.com', '$2b$10$hashedpassword3', '+1234567892');

        -- Insert corresponding preferences for the first user
        INSERT INTO "UserPreferences" ("userId", "defaultTheme", "imagePath")
        SELECT u."id", 'DARK', '/uploads/profiles/john_doe.jpg'
        FROM "Users" u
        WHERE u."email" = 'john.doe@example.com';

        RAISE NOTICE 'Sample data inserted successfully';
    ELSE
        RAISE NOTICE 'Users table already contains data, skipping sample data insertion';
    END IF;
END $$;

-- Commit sample data transaction
COMMIT;

-- Final optimization: analyze tables for better query planning
ANALYZE "Users";
ANALYZE "UserPreferences";

-- Display setup completion summary
DO $$
DECLARE
    user_count INTEGER;
    preference_count INTEGER;
    index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM "Users";
    SELECT COUNT(*) INTO preference_count FROM "UserPreferences";
    SELECT COUNT(*) INTO index_count FROM pg_indexes WHERE tablename IN ('Users', 'UserPreferences');

    RAISE NOTICE '=== PostgreSQL Database Setup Complete ===';
    RAISE NOTICE 'Tables created: Users, UserPreferences';
    RAISE NOTICE 'Users count: %', user_count;
    RAISE NOTICE 'Preferences count: %', preference_count;
    RAISE NOTICE 'Indexes created: %', index_count;
    RAISE NOTICE 'Views created: ActiveUsersWithPreferences';
    RAISE NOTICE 'Functions created: soft_delete_user, restore_user, get_user_statistics';
    RAISE NOTICE 'Triggers created: automatic updatedAt updates';
    RAISE NOTICE '==========================================';
END $$;
