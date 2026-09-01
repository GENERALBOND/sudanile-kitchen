-- ============================================================================
-- Sudanile Kitchen — Database Schema (PostgreSQL reference port)
--
-- This file is a faithful PostgreSQL port of the schema produced by the
-- live Django models and migrations (users, recipes, reviews, favorites,
-- submissions) plus the framework tables Django manages automatically.
--
-- NOTE: Django migrations remain the source of truth. This file is for
-- reference / manual Postgres setups only; do not load it and then run
-- `python manage.py migrate` against the same database, or the two will
-- conflict (migrations rely on the django_migrations bookkeeping table).
--
-- Differences from the older version of this file:
--   * recipes/submissions use prep_hours/prep_minutes/prep_seconds and
--     cook_hours/cook_minutes/cook_seconds instead of the removed
--     preparation_time/cooking_time columns.
--   * Added recipes_recipe.is_flagged / flagged_reason.
--   * Added users_user email-verification columns.
--   * Added all Django framework tables (auth, contenttypes, admin log,
--     sessions, migrations) and the M2M join tables.
--   * Removed the unused uuid-ossp extension and the redundant
--     updated_at triggers (Django sets these via auto_now on every save).
--   * No sample-data inserts (migrations do not seed data).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Django framework tables
-- ----------------------------------------------------------------------------

-- Content types registry
CREATE TABLE django_content_type (
    id SERIAL PRIMARY KEY,
    app_label VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model)
);

-- Permissions (django.contrib.auth)
CREATE TABLE auth_permission (
    id SERIAL PRIMARY KEY,
    content_type_id INTEGER NOT NULL REFERENCES django_content_type (id) ON DELETE CASCADE,
    codename VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename)
);

-- User groups (django.contrib.auth)
CREATE TABLE auth_group (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE auth_group_permissions (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL REFERENCES auth_group (id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES auth_permission (id) ON DELETE CASCADE,
    CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id)
);

-- ----------------------------------------------------------------------------
-- Users (created before django_admin_log, which references users_user)
-- ----------------------------------------------------------------------------

-- Custom user model (replaces Django's auth_user)
CREATE TABLE users_user (
    id BIGSERIAL PRIMARY KEY,
    password VARCHAR(128) NOT NULL,
    last_login TIMESTAMP WITH TIME ZONE,
    is_superuser BOOLEAN NOT NULL,
    username VARCHAR(150) NOT NULL UNIQUE,
    first_name VARCHAR(150) NOT NULL,
    last_name VARCHAR(150) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    is_staff BOOLEAN NOT NULL,
    is_active BOOLEAN NOT NULL,
    date_joined TIMESTAMP WITH TIME ZONE NOT NULL,
    role VARCHAR(10) NOT NULL,
    profile_picture VARCHAR(200),
    bio TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    email_verification_sent_at TIMESTAMP WITH TIME ZONE,
    email_verification_token VARCHAR(100),
    is_email_verified BOOLEAN NOT NULL
);

-- User <-> group many-to-many
CREATE TABLE users_user_groups (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES auth_group (id) ON DELETE CASCADE,
    CONSTRAINT users_user_groups_user_id_group_id_b88eab82_uniq UNIQUE (user_id, group_id)
);

-- User <-> permission many-to-many
CREATE TABLE users_user_user_permissions (
    id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES auth_permission (id) ON DELETE CASCADE,
    CONSTRAINT users_user_user_permissions_user_id_permission_id_43338c45_uniq UNIQUE (user_id, permission_id)
);


-- ----------------------------------------------------------------------------
-- More Django framework tables
-- ----------------------------------------------------------------------------

-- Admin action log (django.contrib.admin)
CREATE TABLE django_admin_log (
    id SERIAL PRIMARY KEY,
    object_id TEXT,
    object_repr VARCHAR(200) NOT NULL,
    action_flag SMALLINT NOT NULL CHECK (action_flag >= 0),
    change_message TEXT NOT NULL,
    content_type_id INTEGER REFERENCES django_content_type (id) ON DELETE SET NULL,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    action_time TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Sessions (django.contrib.sessions)
CREATE TABLE django_session (
    session_key VARCHAR(40) PRIMARY KEY,
    session_data TEXT NOT NULL,
    expire_date TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Migration history (Django migration framework)
CREATE TABLE django_migrations (
    id SERIAL PRIMARY KEY,
    app VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    applied TIMESTAMP WITH TIME ZONE NOT NULL
);


-- ----------------------------------------------------------------------------
-- Content: categories, recipes
-- ----------------------------------------------------------------------------

CREATE TABLE recipes_category (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon VARCHAR(200)
);

CREATE TABLE recipes_recipe (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    instructions JSONB NOT NULL,
    cultural_info TEXT NOT NULL,
    prep_hours INTEGER NOT NULL,
    prep_minutes INTEGER NOT NULL,
    prep_seconds INTEGER NOT NULL,
    cook_hours INTEGER NOT NULL,
    cook_minutes INTEGER NOT NULL,
    cook_seconds INTEGER NOT NULL,
    servings INTEGER NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    image_url VARCHAR(200),
    category_id BIGINT REFERENCES recipes_category (id) ON DELETE SET NULL,
    author_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    average_rating DOUBLE PRECISION NOT NULL,
    total_reviews INTEGER NOT NULL,
    view_count INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_published BOOLEAN NOT NULL,
    is_flagged BOOLEAN NOT NULL,
    flagged_reason TEXT
);


-- ----------------------------------------------------------------------------
-- Reviews and favorites
-- ----------------------------------------------------------------------------

CREATE TABLE reviews_review (
    id BIGSERIAL PRIMARY KEY,
    rating INTEGER NOT NULL,
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    recipe_id BIGINT NOT NULL REFERENCES recipes_recipe (id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    CONSTRAINT reviews_review_user_id_recipe_id_0de9ea21_uniq UNIQUE (user_id, recipe_id)
);

CREATE TABLE favorites_favorite (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    recipe_id BIGINT NOT NULL REFERENCES recipes_recipe (id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE,
    CONSTRAINT favorites_favorite_user_id_recipe_id_4dcbbbf0_uniq UNIQUE (user_id, recipe_id)
);


-- ----------------------------------------------------------------------------
-- Recipe submissions
-- ----------------------------------------------------------------------------

CREATE TABLE submissions_recipesubmission (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    instructions JSONB NOT NULL,
    cultural_info TEXT NOT NULL,
    prep_hours INTEGER NOT NULL,
    prep_minutes INTEGER NOT NULL,
    prep_seconds INTEGER NOT NULL,
    cook_hours INTEGER NOT NULL,
    cook_minutes INTEGER NOT NULL,
    cook_seconds INTEGER NOT NULL,
    servings INTEGER NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    image_url VARCHAR(200),
    category_name VARCHAR(100) NOT NULL,
    status VARCHAR(10) NOT NULL,
    admin_notes TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    user_id BIGINT NOT NULL REFERENCES users_user (id) ON DELETE CASCADE
);


-- ----------------------------------------------------------------------------
-- Indexes (mirrors what Django migrations create on PostgreSQL)
-- ----------------------------------------------------------------------------

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON auth_group_permissions (group_id);
CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON auth_group_permissions (permission_id);
CREATE INDEX auth_permission_content_type_id_2f476e4b ON auth_permission (content_type_id);
CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON django_admin_log (content_type_id);
CREATE INDEX django_admin_log_user_id_c564eba6 ON django_admin_log (user_id);
CREATE INDEX django_session_expire_date_a5c62663 ON django_session (expire_date);
CREATE INDEX favorites_favorite_recipe_id_0bbedd42 ON favorites_favorite (recipe_id);
CREATE INDEX favorites_favorite_user_id_69ee5ed6 ON favorites_favorite (user_id);
CREATE INDEX recipes_recipe_author_id_7274f74b ON recipes_recipe (author_id);
CREATE INDEX recipes_recipe_category_id_6d665355 ON recipes_recipe (category_id);
CREATE INDEX reviews_review_recipe_id_e3770617 ON reviews_review (recipe_id);
CREATE INDEX reviews_review_user_id_875caff2 ON reviews_review (user_id);
CREATE INDEX submissions_recipesubmission_user_id_077705f7 ON submissions_recipesubmission (user_id);
CREATE INDEX users_user_groups_group_id_9afc8d0e ON users_user_groups (group_id);
CREATE INDEX users_user_groups_user_id_5f6f5a90 ON users_user_groups (user_id);
CREATE INDEX users_user_user_permissions_permission_id_0b93982e ON users_user_user_permissions (permission_id);
CREATE INDEX users_user_user_permissions_user_id_20aca447 ON users_user_user_permissions (user_id);


-- ----------------------------------------------------------------------------
-- Optional, NON-migration extras from the original schema (commented out).
-- Uncomment only if you want these beyond what Django manages.
-- ----------------------------------------------------------------------------

-- Ratings integrity check (Django only validates in Python, not in the DB):
-- ALTER TABLE reviews_review ADD CONSTRAINT reviews_review_rating_check
--     CHECK (rating >= 1 AND rating <= 5);

-- Extra query indexes that Django does not create:
-- CREATE INDEX idx_recipe_title ON recipes_recipe (title);
-- CREATE INDEX idx_recipe_created ON recipes_recipe (created_at);
-- CREATE INDEX idx_recipe_rating ON recipes_recipe (average_rating);
-- CREATE INDEX idx_submission_status ON submissions_recipesubmission (status);
