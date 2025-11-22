

-- 1. DATABASE AND SCHEMA CREATION
-- =====================================================
-- Drop existing database if exists (for reusability)
DROP DATABASE IF EXISTS social_media_platform;

-- Create new database
CREATE DATABASE social_media_platform
    WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Connect to the database
\c social_media_platform

-- Create schema for organizing database objects
CREATE SCHEMA IF NOT EXISTS social_network;

-- Set search path to use the schema by default
SET search_path TO social_network, public;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLE CREATION
-- =====================================================
-- Table: USERS
-- Core user account information

CREATE TABLE IF NOT EXISTS social_network.users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    fullname VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Constraints
    -- CHECK: Email must contain @ symbol (basic validation)
    CONSTRAINT chk_users_email_valid CHECK (LOWER(email) ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    -- CHECK: Username must be at least 3 characters
    CONSTRAINT chk_users_username_length CHECK (LENGTH(TRIM(username)) >= 3),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_users_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- CHECK: Password hash must not be empty
    CONSTRAINT chk_users_password_not_empty CHECK (LENGTH(TRIM(password_hash)) > 0),
    -- CHECK: Fullname must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_users_fullname_not_empty CHECK (LENGTH(TRIM(fullname)) > 0)
   );

COMMENT ON TABLE social_network.users IS 'Core user authentication and account data';
COMMENT ON COLUMN social_network.users.user_id IS 'UUID primary key for users';
COMMENT ON COLUMN social_network.users.password_hash IS 'Hashed password using bcrypt or similar algorithm';
COMMENT ON COLUMN social_network.users.is_active IS 'Account status - false for deactivated accounts';
COMMENT ON COLUMN social_network.users.created_at IS 'Timestamp with timezone when account was created';

-- Create index on lowercase email and username for case-insensitive lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON social_network.users(LOWER(email));
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_lower ON social_network.users(LOWER(username));

-- Table: LOCATIONS
-- Geographic location information for users and posts

CREATE TABLE IF NOT EXISTS social_network.locations (
    location_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    post_id UUID,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Country must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_locations_country_not_empty CHECK (LENGTH(TRIM(country)) > 0),
    -- CHECK: City must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_locations_city_not_empty CHECK (LENGTH(TRIM(city)) > 0),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_locations_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys (will be added after POSTS table is created for post_id)
    CONSTRAINT fk_locations_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE
);

ALTER TABLE social_network.locations
ADD CONSTRAINT locations_unique UNIQUE (user_id, country, city);

COMMENT ON TABLE social_network.locations IS 'Geographic location data for users and posts';
COMMENT ON COLUMN social_network.locations.user_id IS 'Optional reference to user who created/owns this location';
COMMENT ON COLUMN social_network.locations.post_id IS 'Optional reference to post tagged with this location';

-- Table: USER_PROFILES
-- Extended user profile information

CREATE TABLE IF NOT EXISTS social_network.user_profiles (
    profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender VARCHAR(20) NOT NULL,
    location_id UUID,
    bio TEXT,
    
    -- Constraints
    -- CHECK: Gender can only be specific values (Requirement #6.3)
    CONSTRAINT chk_profiles_gender CHECK (LOWER(gender) IN ('male', 'female', 'prefer_not_to_say')),
    -- CHECK: Date of birth must be reasonable (between 1900 and today)
    CONSTRAINT chk_profiles_dob_valid CHECK (
        date_of_birth >= '1900-01-01'::DATE AND 
        date_of_birth <= CURRENT_DATE ),
    -- CHECK: Date of birth must be after January 1, 2000 for platform usage (Requirement #6.1)
    -- Note: This might be too restrictive in practice, but following requirements
    -- Removed the following Check constraint due to redundancy
    --CONSTRAINT chk_profiles_dob_after_2000 CHECK (date_of_birth > '2000-01-01'::DATE),
    -- CHECK: Full name must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_profiles_fullname_not_empty CHECK (LENGTH(TRIM(full_name)) > 0),
    -- UNIQUE: One profile per user (Requirement #6.4)
    CONSTRAINT uq_profiles_user_id UNIQUE (user_id),
    -- Foreign Keys
    CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_profiles_location FOREIGN KEY (location_id) 
        REFERENCES social_network.locations(location_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON social_network.user_profiles(user_id);

COMMENT ON TABLE social_network.user_profiles IS 'Extended user profile information';
COMMENT ON COLUMN social_network.user_profiles.gender IS 'User gender identity - restricted to specific values';
COMMENT ON COLUMN social_network.user_profiles.bio IS 'User biography - optional field';
COMMENT ON COLUMN social_network.user_profiles.date_of_birth IS 'User date of birth for age verification';


-- Table: POSTS
-- User-generated content posts

CREATE TABLE IF NOT EXISTS social_network.posts (
    post_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    location_id UUID,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Constraints
    -- CHECK: Content must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_posts_content_not_empty CHECK (LENGTH(TRIM(content)) > 0),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_posts_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- CHECK: Updated date must be >= created date
    CONSTRAINT chk_posts_updated_after_created CHECK (updated_at >= created_at),
    -- Foreign Keys
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_posts_location FOREIGN KEY (location_id) 
        REFERENCES social_network.locations(location_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON social_network.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON social_network.posts(created_at DESC);

COMMENT ON TABLE social_network.posts IS 'User-generated content posts';
COMMENT ON COLUMN social_network.posts.is_public IS 'Visibility flag - true for public, false for private';
COMMENT ON COLUMN social_network.posts.content IS 'Post text content';
COMMENT ON COLUMN social_network.posts.updated_at IS 'Last update timestamp';

-- Add foreign key constraint to locations.post_id now that posts table exists
ALTER TABLE social_network.locations
ADD CONSTRAINT fk_locations_post FOREIGN KEY (post_id) 
    REFERENCES social_network.posts(post_id) ON DELETE CASCADE;

-- Table: MEDIA
-- Media files attached to posts

CREATE TABLE IF NOT EXISTS social_network.media (
    media_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL,
    media_type VARCHAR(50) NOT NULL,
    url VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Media type can only be specific values (Requirement #6.3)
    CONSTRAINT chk_media_type CHECK (LOWER(media_type) IN ('image', 'video', 'audio', 'document')),
    -- CHECK: URL must not be empty and should start with http/https (Requirement #6.5)
    CONSTRAINT chk_media_url_valid CHECK (LOWER(url) ~* '^https?://.*'),
    -- CHECK: Uploaded date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_media_uploaded_date CHECK (uploaded_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys
    CONSTRAINT fk_media_post FOREIGN KEY (post_id) 
        REFERENCES social_network.posts(post_id) ON DELETE CASCADE
);

COMMENT ON TABLE social_network.media IS 'Media files associated with posts';
COMMENT ON COLUMN social_network.media.media_type IS 'Type of media: image, video, audio, or document';
COMMENT ON COLUMN social_network.media.url IS 'Full URL to the media file on CDN or storage';

-- Table: HASHTAGS

CREATE TABLE IF NOT EXISTS social_network.hashtags (
    hashtag_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    
    -- Constraints
    -- CHECK: Hashtag name format validation (alphanumeric and underscore only)
    CONSTRAINT chk_hashtags_name_format CHECK (name ~ '^[a-zA-Z0-9_]+$'),
    -- CHECK: Hashtag name must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_hashtags_name_not_empty CHECK (LENGTH(TRIM(name)) > 0)
);

COMMENT ON TABLE social_network.hashtags IS 'Hashtag definitions for content categorization';
COMMENT ON COLUMN social_network.hashtags.name IS 'Hashtag text without # symbol';

-- Create index on lowercase hashtag name for case-insensitive lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_hashtags_name_lower ON social_network.hashtags(LOWER(name));

-- Table: POST_HASHTAGS
-- Many-to-many relationship between posts and hashtags

CREATE TABLE IF NOT EXISTS social_network.post_hashtags (
    post_id UUID NOT NULL,
    hashtag_id UUID NOT NULL,
    
    -- Constraints
    PRIMARY KEY (post_id, hashtag_id),
    -- Foreign Keys
    CONSTRAINT fk_post_hashtags_post FOREIGN KEY (post_id) 
        REFERENCES social_network.posts(post_id) ON DELETE CASCADE,
    CONSTRAINT fk_post_hashtags_hashtag FOREIGN KEY (hashtag_id) 
        REFERENCES social_network.hashtags(hashtag_id) ON DELETE CASCADE
);

COMMENT ON TABLE social_network.post_hashtags IS 'Association between posts and hashtags';

-- Table: COMMENTS

CREATE TABLE IF NOT EXISTS social_network.comments (
    comment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL,
    user_id UUID NOT NULL,
    parent_comment_id UUID,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Content must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_comments_content_not_empty CHECK (LENGTH(TRIM(content)) > 0),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_comments_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id) 
        REFERENCES social_network.posts(post_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_parent FOREIGN KEY (parent_comment_id) 
        REFERENCES social_network.comments(comment_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_comments_post_id ON social_network.comments(post_id);

ALTER TABLE social_network.comments
ADD CONSTRAINT comments_unique UNIQUE (post_id, user_id, content);

COMMENT ON TABLE social_network.comments IS 'User comments on posts with nested reply support';
COMMENT ON COLUMN social_network.comments.parent_comment_id IS 'Reference to parent comment for nested replies';

-- Table: LIKES
-- User likes on posts and comments

CREATE TABLE IF NOT EXISTS social_network.likes (
    like_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    post_id UUID,
    comment_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Like must be for either post OR comment, not both or neither
    CONSTRAINT chk_likes_target CHECK (
        (post_id IS NOT NULL AND comment_id IS NULL) OR 
        (post_id IS NULL AND comment_id IS NOT NULL)
    ),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_likes_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- UNIQUE: User can like a post only once (Requirement #6.4)
    CONSTRAINT uq_likes_user_post UNIQUE (user_id, post_id),
    -- UNIQUE: User can like a comment only once (Requirement #6.4)
    CONSTRAINT uq_likes_user_comment UNIQUE (user_id, comment_id),
    -- Foreign Keys
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_post FOREIGN KEY (post_id) 
        REFERENCES social_network.posts(post_id) ON DELETE CASCADE,
    CONSTRAINT fk_likes_comment FOREIGN KEY (comment_id) 
        REFERENCES social_network.comments(comment_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_likes_post_id ON social_network.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON social_network.likes(user_id);

COMMENT ON TABLE social_network.likes IS 'User likes on posts or comments';
COMMENT ON CONSTRAINT chk_likes_target ON social_network.likes IS 'Ensures like is for either post OR comment, not both';

-- Table: SHARES

CREATE TABLE IF NOT EXISTS social_network.shares (
    share_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    post_id UUID NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_shares_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys
    CONSTRAINT fk_shares_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_shares_post FOREIGN KEY (post_id) 
        REFERENCES social_network.posts(post_id) ON DELETE CASCADE
);

ALTER TABLE social_network.shares
ADD CONSTRAINT shares_unique UNIQUE (user_id, post_id, comment);

COMMENT ON TABLE social_network.shares IS 'User post sharing activity';
COMMENT ON COLUMN social_network.shares.comment IS 'Optional comment added when sharing';

-- Table: FRIENDSHIPS
-- Friendship relationships between users

CREATE TABLE IF NOT EXISTS social_network.friendships (
    friendship_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_a_id UUID NOT NULL,
    user_b_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Status can only be specific values (Requirement #6.3)
    CONSTRAINT chk_friendships_status CHECK (LOWER(status) IN ('pending', 'accepted', 'rejected', 'blocked')),
    -- CHECK: Users cannot be friends with themselves
    CONSTRAINT chk_friendships_not_self CHECK (user_a_id != user_b_id),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_friendships_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- UNIQUE: Prevent duplicate friendship pairs (Requirement #6.4)
    CONSTRAINT uq_friendships_pair UNIQUE (user_a_id, user_b_id),
    -- Foreign Keys
    CONSTRAINT fk_friendships_user_a FOREIGN KEY (user_a_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friendships_user_b FOREIGN KEY (user_b_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE
);

COMMENT ON TABLE social_network.friendships IS 'Friendship relationships between users';
COMMENT ON COLUMN social_network.friendships.status IS 'Friendship status: pending, accepted, rejected, or blocked';

-- Table: FOLLOWS

CREATE TABLE IF NOT EXISTS social_network.follows (
    follow_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL,
    followee_id UUID NOT NULL,
    followed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Users cannot follow themselves
    CONSTRAINT chk_follows_not_self CHECK (follower_id != followee_id),
    -- CHECK: Followed date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_follows_followed_date CHECK (followed_at > '2000-01-01'::TIMESTAMPTZ),
    -- UNIQUE: Prevent duplicate follow relationships (Requirement #6.4)
    CONSTRAINT uq_follows_pair UNIQUE (follower_id, followee_id),
    -- Foreign Keys
    CONSTRAINT fk_follows_follower FOREIGN KEY (follower_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_follows_followee FOREIGN KEY (followee_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON social_network.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followee_id ON social_network.follows(followee_id);

COMMENT ON TABLE social_network.follows IS 'Asymmetric user following relationships';
COMMENT ON COLUMN social_network.follows.follower_id IS 'User who is following';
COMMENT ON COLUMN social_network.follows.followee_id IS 'User being followed';

-- Table: MESSAGES
-- Direct messages between users

CREATE TABLE IF NOT EXISTS social_network.messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL,
    receiver_id UUID NOT NULL,
    body TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Constraints
    -- CHECK: Body must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_messages_body_not_empty CHECK (LENGTH(TRIM(body)) > 0),
    -- CHECK: Users cannot message themselves
    CONSTRAINT chk_messages_not_self CHECK (sender_id != receiver_id),
    -- CHECK: Sent date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_messages_sent_date CHECK (sent_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys
    CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_messages_receiver FOREIGN KEY (receiver_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON social_network.messages(receiver_id);

ALTER TABLE social_network.messages
ADD CONSTRAINT messages_unique UNIQUE (sender_id, receiver_id, body);

COMMENT ON TABLE social_network.messages IS 'Direct messages between users';
COMMENT ON COLUMN social_network.messages.is_read IS 'Message read status';

-- Table: NOTIFICATIONS

CREATE TABLE IF NOT EXISTS social_network.notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    message VARCHAR(500) NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    -- CHECK: Type can only be specific values (Requirement #6.3)
    CONSTRAINT chk_notifications_type CHECK (LOWER(TYPE) IN ('like', 'comment', 'share', 'follow', 'friend_request', 'message', 'mention')),
    -- CHECK: Message must not be empty (Requirement #6.5 - NOT NULL)
    CONSTRAINT chk_notifications_message_not_empty CHECK (LENGTH(TRIM(message)) > 0),
    -- CHECK: Created date must be after January 1, 2000 (Requirement #6.1)
    CONSTRAINT chk_notifications_created_date CHECK (created_at > '2000-01-01'::TIMESTAMPTZ),
    -- Foreign Keys
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) 
        REFERENCES social_network.users(user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON social_network.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON social_network.notifications(user_id, is_read);

ALTER TABLE social_network.notifications
ADD CONSTRAINT notifications_unique UNIQUE (user_id, message);

COMMENT ON TABLE social_network.notifications IS 'User notifications for platform activities';
COMMENT ON COLUMN social_network.notifications.type IS 'Notification type: like, comment, share, follow, etc.';


-- 3. DATA POPULATION
-- =====================================================

-- Insert Users
INSERT INTO social_network.users 
    (username, email, password_hash, fullname, created_at, is_active)
SELECT v.username, v.email, v.password_hash, v.fullname, v.created_at, v.is_active
FROM (
    VALUES 
        ('alice_johnson', 'alice.johnson@email.com', '$2b$12$KIXxBjQZabcdefghijklm', 'Alice Johnson', '2023-01-15 10:30:00+00'::timestamp, TRUE),
        ('bob_smith', 'bob.smith@email.com', '$2b$12$KIXxBjQZnopqrstuvwxyz', 'Bob Smith', '2023-03-20 14:45:00+00'::timestamp , TRUE),
        ('carol_white', 'carol.white@email.com', '$2b$12$KIXxBjQZ123456789012', 'Carol White', '2023-05-10 09:15:00+00'::timestamp, TRUE),
        ('david_brown', 'david.brown@email.com', '$2b$12$KIXxBjQZabcxyz987654', 'David Brown', '2023-07-22 16:20:00+00'::timestamp, TRUE),
        ('emma_davis',  'emma.davis@email.com', '$2b$12$KIXxBjQZqwerty123456', 'Emma Davis',  '2023-09-05 11:00:00+00'::timestamp, FALSE)
) AS v (username, email, password_hash, fullname, created_at, is_active)
WHERE NOT EXISTS (
    SELECT 1 
    FROM social_network.users u
    WHERE LOWER(u.username) = LOWER(v.username)
);

-- Insert Locations
INSERT INTO social_network.locations (user_id, country, city, created_at)
SELECT 
    v.user_id,
    v.country,
    v.city,
    v.created_at
FROM (
    VALUES
        -- alice_johnson
        ((SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'), 
         'United States', 'Los Angeles', '2023-01-15 10:35:00+00'::timestamp),

        -- bob_smith
        ((SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
         'United States', 'New York', '2023-03-20 14:50:00+00'::timestamp),

        -- carol_white
        ((SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'), 
        'United States', 'Austin', '2023-05-10 09:20:00+00'::timestamp),
        
        -- david_brown
        ((SELECT user_id FROM social_network.users WHERE LOWER(username) = 'david_brown'), 
        'United States', 'Miami', '2023-07-22 16:25:00+00'::timestamp)
) AS v (user_id, country, city, created_at)
ON CONFLICT DO NOTHING;


-- Insert User Profiles
INSERT INTO social_network.user_profiles 
    (user_id, full_name, date_of_birth, gender, location_id, bio)
SELECT 
    v.user_id,
    v.full_name,
    v.date_of_birth,
    v.gender,
    v.location_id,
    v.bio
FROM (
    -- Alice Johnson
    SELECT
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson') AS user_id,
        'Alice Marie Johnson' AS full_name,
        '2001-03-15'::date AS date_of_birth,
        'female' AS gender,
        (SELECT location_id 
         FROM social_network.locations 
         WHERE LOWER(city) = 'los angeles' 
           AND LOWER(country) = 'united states') AS location_id,
        'Photography enthusiast and travel lover. Exploring the world one picture at a time.' AS bio

    UNION ALL

    -- Bob Smith
    SELECT
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        'Robert James Smith',
        '2000-07-22'::date,
        'male',
        (SELECT location_id 
         FROM social_network.locations 
         WHERE LOWER(city) = 'new york' 
           AND LOWER(country) = 'united states'),
        'Tech blogger and software developer. Passionate about AI and web technologies.'

    UNION ALL

    -- Carol White
    SELECT
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        'Carol Ann White',
        '2002-11-08'::date,
        'female',
        (SELECT location_id 
         FROM social_network.locations 
         WHERE LOWER(city) = 'austin'
           AND LOWER(country) = 'united states'),
        'Fitness coach and nutrition expert. Helping people achieve their health goals.'
) AS v
WHERE v.user_id IS NOT NULL
  AND NOT EXISTS (
        SELECT 1 
        FROM social_network.user_profiles p
        WHERE p.user_id = v.user_id
  );


-- Insert Posts
INSERT INTO social_network.posts ( user_id, location_id, content, created_at, updated_at, is_public)
SELECT p.user_id, p.location_id, p.content, p.created_at, p.updated_at, p.is_public
FROM (
    VALUES
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT location_id FROM social_network.locations WHERE LOWER(city) = 'los angeles' LIMIT 1),
        'Sunset over Santa Monica Pier — captured this evening. #sunset #losangeles',
        '2023-08-10 19:12:00+00'::timestamptz,
        '2023-08-10 19:12:00+00'::timestamptz,
        TRUE
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        (SELECT location_id FROM social_network.locations WHERE LOWER(city) = 'new york' LIMIT 1),
        'New blog post: Building accessible web apps with modern JS frameworks. Link in bio.',
        '2023-09-02 08:45:00+00'::timestamptz,
        '2023-09-02 08:45:00+00'::timestamptz,
        TRUE
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'emma_davis'),
        (SELECT location_id FROM social_network.locations WHERE LOWER(city) = 'miami' LIMIT 1),
        'Weekend beach reads: three recommendations for your next trip. #books #beach',
        '2023-10-05 15:30:00+00'::timestamptz,
        '2023-10-05 15:30:00+00'::timestamptz,
        FALSE
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT location_id FROM social_network.locations WHERE LOWER(city) = 'los angeles' LIMIT 1),
        'Exploring LA cafes — found a great spot for editing photos. Highly recommend the cappuccino!',
        '2023-11-01 09:10:00+00'::timestamptz,
        '2023-11-01 09:10:00+00'::timestamptz,
        TRUE
    )
) AS p(user_id, location_id, content, created_at, updated_at, is_public)
WHERE p.user_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM social_network.posts t
      WHERE t.user_id = p.user_id
        AND t.content = p.content
        AND t.created_at = p.created_at
  );

-- Insert Media
INSERT INTO social_network.media (post_id, media_type, url, uploaded_at)
SELECT m.post_id, m.media_type, m.url, m.uploaded_at
FROM (
    VALUES
    ( 
      (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
      'image',
      'https://cdn.example.com/images/santa_monica_sunset.jpg',
      '2023-08-10 19:15:00+00'::timestamptz
    ),
    (
      (SELECT post_id FROM social_network.posts WHERE content ILIKE '%accessible web apps%' LIMIT 1),
      'document',
      'https://blog.example.com/posts/accessible-web-apps.pdf',
      '2023-09-02 09:00:00+00'::timestamptz
    ),
    ( 
      (SELECT post_id FROM social_network.posts WHERE content ILIKE '%30 minutes HIIT%' LIMIT 1),
      'video',
      'https://cdn.example.com/videos/hiit_routine.mp4',
      '2023-09-15 06:30:00+00'::timestamptz
    ),
    ( 
      (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Throwback to my university days%' LIMIT 1),
      'image',
      'https://cdn.example.com/images/throwback_university.jpg',
      '2023-07-01 12:05:00+00'::timestamptz
)) AS m(post_id, media_type, url, uploaded_at)
WHERE m.post_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM social_network.media mm WHERE mm.post_id = m.post_id AND mm.url = m.url
  );

-- Insert Hashtags and Post Hashtags
INSERT INTO social_network.hashtags (name)
VALUES
    ('sunset'),
    ('losangeles'),
    ('fitness'),
    ('wellness'),
    ('webdev'),
    ('books')
ON CONFLICT (LOWER(name)) DO NOTHING;

-- Map posts to hashtags using content matching (and explicit mappings)
INSERT INTO social_network.post_hashtags (post_id, hashtag_id)
SELECT p.post_id, h.hashtag_id
FROM social_network.posts p
INNER JOIN social_network.hashtags h
  ON (
       (LOWER(h.name) = 'sunset' AND p.content ILIKE '%sunset%')
    OR (LOWER(h.name) = 'losangeles' AND (p.content ILIKE '%losangeles%' OR p.content ILIKE '%Los Angeles%'))
    OR (LOWER(h.name) = 'fitness' AND (p.content ILIKE '%HIIT%' OR p.content ILIKE '%fitness%'))
    OR (LOWER(h.name) = 'webdev' AND p.content ILIKE '%web%')
    OR (LOWER(h.name) = 'books' AND p.content ILIKE '%books%')
  )
ON CONFLICT DO NOTHING;

-- Add explicit mappings (if automatic matching misses)
INSERT INTO social_network.post_hashtags (post_id, hashtag_id)
SELECT pmap.post_id, h.hashtag_id
FROM (
    VALUES
        ((SELECT post_id FROM social_network.posts WHERE content ILIKE '%Santa Monica Pier%' LIMIT 1), 'sunset'),
        ((SELECT post_id FROM social_network.posts WHERE content ILIKE '%Santa Monica Pier%' LIMIT 1), 'losangeles'),
        ((SELECT post_id FROM social_network.posts WHERE content ILIKE '%HIIT%' LIMIT 1), 'fitness'),
        ((SELECT post_id FROM social_network.posts WHERE content ILIKE '%accessible web apps%' LIMIT 1), 'webdev'),
        ((SELECT post_id FROM social_network.posts WHERE content ILIKE '%Weekend beach reads%' LIMIT 1), 'books')
) AS pmap(post_id, tagname)
INNER JOIN social_network.hashtags h ON LOWER(h.name) = LOWER(pmap.tagname)
WHERE pmap.post_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Insert Comments
INSERT INTO social_network.comments (post_id, user_id, parent_comment_id, content, created_at)
VALUES
    (
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        NULL,
        'Stunning shot! Which lens did you use?',
        '2023-08-10 20:00:00+00'::timestamptz
    ),
    (
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        NULL,
        'Thanks, Bob! I used a 35mm prime and slight exposure boost.',
        '2023-08-10 20:05:00+00'::timestamptz
    ),
    (
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%New blog post: Building accessible web apps%' LIMIT 1),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        NULL,
        'Great resource, Bob — bookmarked for later reading.',
        '2023-09-02 10:00:00+00'::timestamptz
    ),
     (
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Exploring LA cafes%' LIMIT 1),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        NULL,
        'Thanks David! Let me know which one you liked most.',
        '2023-11-01 10:10:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;

-- If the last comment should be a reply to David's comment, update parent_comment_id 
UPDATE social_network.comments t
SET parent_comment_id = parent.comment_id
FROM (
    SELECT child.comment_id AS child_id, parent.comment_id AS comment_id
    FROM social_network.comments child
    JOIN social_network.comments parent
      ON child.content ILIKE '%Thanks David! Let me know which one you liked most.%'
     AND parent.content ILIKE '%I will check the cafe%'
) AS parent
WHERE t.comment_id = parent.child_id
  AND t.parent_comment_id IS NULL;

-- Insert likes
INSERT INTO social_network.likes (user_id, post_id, comment_id, created_at)
VALUES
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
        NULL,
        '2023-08-10 20:01:00+00'::timestamptz
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
        NULL,
        '2023-09-15 07:15:00+00'::timestamptz
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%New blog post: Building accessible web apps%' LIMIT 1),
        NULL,
        '2023-09-02 10:30:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;

-- Comment likes
INSERT INTO social_network.likes (user_id, post_id, comment_id, created_at)
SELECT 
       (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
       NULL,
       c.comment_id,
       '2023-08-10 20:06:00+00'::timestamptz
FROM social_network.comments c
WHERE c.content ILIKE '%Stunning shot! Which lens did you use?%'
  AND NOT EXISTS (
      SELECT 1 FROM social_network.likes lk
      WHERE lk.user_id = (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson')
        AND lk.comment_id = c.comment_id
  );

INSERT INTO social_network.likes (user_id, post_id, comment_id, created_at)
SELECT 
       (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'david_brown'),
       NULL,
       c.comment_id,
       '2023-11-01 10:20:00+00'::timestamptz
FROM social_network.comments c
WHERE c.content ILIKE '%Thanks, Bob! I used a 35mm prime%'
  AND NOT EXISTS (
      SELECT 1 FROM social_network.likes lk
      WHERE lk.user_id = (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'david_brown')
        AND lk.comment_id = c.comment_id
  );

-- Insert Shares
INSERT INTO social_network.shares (user_id, post_id, comment, created_at)
VALUES
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%Sunset over Santa Monica Pier%' LIMIT 1),
        'Beautiful — sharing with my clients for inspiration.',
        '2023-08-11 07:00:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'david_brown'),
        (SELECT post_id FROM social_network.posts WHERE content ILIKE '%New blog post: Building accessible web apps%' LIMIT 1),
        'Solid write-up — sharing for devs interested in a11y.',
        '2023-09-03 09:00:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;

-- Insert Friendships
INSERT INTO social_network.friendships (user_a_id, user_b_id, status, created_at)
VALUES
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        'accepted',
        '2023-02-01 09:00:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        'pending',
        '2023-04-01 10:00:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'david_brown'),
        'accepted',
        '2023-06-15 16:00:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;

-- Insert Follows
INSERT INTO social_network.follows (follower_id, followee_id, followed_at)
VALUES
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        '2023-08-11 09:00:00+00'::timestamptz
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'emma_davis'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        '2023-10-06 12:00:00+00'::timestamptz
    ),
    (
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        '2023-01-20 13:00:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;


-- Insert Messages
INSERT INTO social_network.messages (sender_id, receiver_id, body, sent_at, is_read)
VALUES
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        'Hey Bob — would you be open to a short interview for my photography blog?',
        '2023-08-15 11:00:00+00'::timestamptz,
        FALSE
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        'Hi Alice — sure, that sounds great. I am free Friday afternoon.',
        '2023-08-15 11:10:00+00'::timestamptz,
        FALSE
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'emma_davis'),
        'Congrats on your new job! When do you start?',
        '2023-09-20 09:30:00+00'::timestamptz,
        TRUE
    )
ON CONFLICT DO NOTHING;


-- Insert Notifications
INSERT INTO social_network.notifications (user_id, type, message, is_read, created_at)
VALUES
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'alice_johnson'),
        'like',
        'Bob Smith liked your photo.',
        FALSE,
        '2023-08-10 20:02:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'bob_smith'),
        'comment',
        'Carol White commented on your post: "Great resource, Bob — bookmarked for later reading."',
        FALSE,
        '2023-09-02 10:05:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'carol_white'),
        'follow',
        'Alice Johnson started following you.',
        FALSE,
        '2023-08-11 09:01:00+00'::timestamptz
    ),
    (
        
        (SELECT user_id FROM social_network.users WHERE LOWER(username) = 'emma_davis'),
        'friend_request',
        'Carol White sent you a friend request.',
        FALSE,
        '2023-10-01 11:31:00+00'::timestamptz
    )
ON CONFLICT DO NOTHING;

-- 5. ADD record_ts to every table, populate existing rows and set NOT NULL
-- =========================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'social_network' AND table_type = 'BASE TABLE'
    LOOP
        -- Add column if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'social_network'
              AND table_name = r.table_name
              AND column_name = 'record_ts'
        ) THEN
            EXECUTE format('ALTER TABLE social_network.%I ADD COLUMN record_ts DATE DEFAULT current_date;', r.table_name);
        END IF;

        -- Update NULL values to current_date
        EXECUTE format('UPDATE social_network.%I SET record_ts = current_date WHERE record_ts IS NULL;', r.table_name);

        -- Ensure NOT NULL
        EXECUTE format('ALTER TABLE social_network.%I ALTER COLUMN record_ts SET NOT NULL;', r.table_name);
    END LOOP;
END$$;
