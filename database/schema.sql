-- Sudanile Kitchen Database Schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Django's auth_user)
CREATE TABLE users_user (
    id SERIAL PRIMARY KEY,
    password VARCHAR(128) NOT NULL,
    last_login TIMESTAMP WITH TIME ZONE,
    is_superuser BOOLEAN DEFAULT FALSE,
    username VARCHAR(150) UNIQUE NOT NULL,
    first_name VARCHAR(150),
    last_name VARCHAR(150),
    email VARCHAR(254) UNIQUE NOT NULL,
    is_staff BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    date_joined TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    role VARCHAR(10) DEFAULT 'user',
    profile_picture VARCHAR(200),
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories table
CREATE TABLE recipes_category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon VARCHAR(200)
);

-- Recipes table
CREATE TABLE recipes_recipe (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    instructions JSONB NOT NULL,
    cultural_info TEXT,
    preparation_time INTEGER NOT NULL,
    cooking_time INTEGER NOT NULL,
    servings INTEGER DEFAULT 4,
    difficulty VARCHAR(20) DEFAULT 'medium',
    image_url VARCHAR(200),
    video_url VARCHAR(200),
    category_id INTEGER REFERENCES recipes_category(id) ON DELETE SET NULL,
    author_id INTEGER NOT NULL REFERENCES users_user(id) ON DELETE CASCADE,
    average_rating FLOAT DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_published BOOLEAN DEFAULT TRUE
);

-- Reviews table
CREATE TABLE reviews_review (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users_user(id) ON DELETE CASCADE,
    recipe_id INTEGER NOT NULL REFERENCES recipes_recipe(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, recipe_id)
);

-- Favorites table
CREATE TABLE favorites_favorite (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users_user(id) ON DELETE CASCADE,
    recipe_id INTEGER NOT NULL REFERENCES recipes_recipe(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, recipe_id)
);

-- Recipe Submissions table
CREATE TABLE submissions_recipesubmission (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users_user(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    ingredients JSONB NOT NULL,
    instructions JSONB NOT NULL,
    cultural_info TEXT,
    preparation_time INTEGER NOT NULL,
    cooking_time INTEGER NOT NULL,
    servings INTEGER DEFAULT 4,
    difficulty VARCHAR(20) NOT NULL,
    image_url VARCHAR(200),
    video_url VARCHAR(200),
    category_name VARCHAR(100) NOT NULL,
    status VARCHAR(10) DEFAULT 'pending',
    admin_notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reviewed_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for performance
CREATE INDEX idx_recipe_title ON recipes_recipe(title);
CREATE INDEX idx_recipe_category ON recipes_recipe(category_id);
CREATE INDEX idx_recipe_author ON recipes_recipe(author_id);
CREATE INDEX idx_recipe_created ON recipes_recipe(created_at);
CREATE INDEX idx_recipe_rating ON recipes_recipe(average_rating);
CREATE INDEX idx_review_recipe ON reviews_review(recipe_id);
CREATE INDEX idx_favorite_user ON favorites_favorite(user_id);
CREATE INDEX idx_submission_status ON submissions_recipesubmission(status);

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users_user
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recipes_updated_at BEFORE UPDATE ON recipes_recipe
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON reviews_review
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample categories
INSERT INTO recipes_category (name, description) VALUES
('Main Dish', 'Hearty and satisfying main courses'),
('Stew', 'Traditional South Sudanese stews'),
('Soup', 'Warming and nutritious soups'),
('Bread', 'Freshly baked traditional breads'),
('Side Dish', 'Complementary side dishes'),
('Beverage', 'Traditional drinks and beverages');