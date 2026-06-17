🍽️ Sudanile Kitchen
Preserving South Sudanese Culinary Heritage

Sudanile Kitchen is a digital platform dedicated to documenting, preserving, and promoting South Sudanese culinary heritage through recipes, cooking guides, and cultural food information.

📱 Features
For Users
✅ Browse Recipes - Explore authentic South Sudanese recipes

✅ Search & Filter - Find recipes by name, ingredients, or category

✅ Save Favorites - Build your personal recipe collection

✅ Rate & Review - Share your experience with the community

✅ Submit Recipes - Contribute your family recipes

✅ Guest Mode - Browse without creating an account

✅ Responsive Design - Works on mobile, tablet, and desktop

For Admins
✅ Content Management - Create, edit, and delete recipes

✅ Approve Submissions - Review community recipe submissions

✅ User Management - Manage users and permissions

✅ Analytics - Track recipe views and user engagement

Security Features
✅ JWT Authentication - Secure token-based authentication

✅ Email Verification - Verify user emails before login

✅ Rate Limiting - Protect against abuse (4 requests/hour)

✅ CORS Protection - Secure cross-origin requests

✅ SQL Injection Prevention - Django ORM protection

✅ XSS Prevention - Auto-escaping of user input

🛠️ Technology Stack
Frontend
Flutter 3.24+ - Cross-platform mobile & web framework

Dart - Programming language

Provider - State management

HTTP - API communication

Shared Preferences - Local storage

Cached Network Image - Image caching

Backend
Django 4.2 - Web framework

Django REST Framework - API development

JWT - Authentication

SQLite - Database (development)

PostgreSQL - Database (production)

CORS Headers - Cross-origin resource sharing


How to run the application. 
Prerequisites
Python 3.12+ - https://www.python.org/downloads/

Flutter 3.24+ - https://flutter.dev/docs/get-started/install

Git - https://git-scm.com/downloads

1. Clone the Repository
bash
git clone https://github.com/yourusername/sudanile-kitchen.git
cd sudanile-kitchen


2. Setup Backend
bash
cd backend

# Create virtual environment
python -m venv venv
source venv/Scripts/activate  # Windows
# or
source venv/bin/activate      # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start server
python manage.py runserver


3. Setup Frontend
bash
cd mobile

# Install dependencies
flutter pub get

# Run the app
flutter run -d chrome


4. Access the Application
Service	URL
Frontend	http://localhost:xxxxx
Backend API	http://localhost:8000/api/
Admin Panel	http://localhost:8000/admin/
API Documentation	http://localhost:8000/swagger/
📝 API Endpoints
Authentication
Method	Endpoint	Description
POST	/api/users/register/	Register new user
POST	/api/users/login/	Login user
GET	/api/users/profile/	Get user profile
POST	/api/users/forgot-password/	Request password reset
POST	/api/users/reset-password/	Reset password
Recipes
Method	Endpoint	Description
GET	/api/recipes/	List all recipes
GET	/api/recipes/{id}/	Get recipe details
POST	/api/recipes/create/	Create recipe (admin)
GET	/api/recipes/categories/	List categories
Community
Method	Endpoint	Description
GET	/api/favorites/	Get user favorites
POST	/api/favorites/add/	Add to favorites
DELETE	/api/favorites/remove/{id}/	Remove from favorites
POST	/api/submissions/create/	Submit recipe for review
🔒 Security Features
Authentication
JWT (JSON Web Token) based authentication

Token expires after 24 hours

Refresh token for extending sessions

Rate Limiting
Anonymous users: 4 requests/hour

Authenticated users: 40 requests/hour

Login attempts: 5/hour

Registration attempts: 3/hour

Data Protection
Password hashing with PBKDF2

CORS protection

SQL injection prevention (Django ORM)

XSS prevention (auto-escaping)

CSRF protection

🧪 Testing
Run Security Tests
bash
cd "/d/NEW PROJECT"
python security_test.py
Test API with Curl
bash
# Register
curl -X POST http://localhost:8000/api/users/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"Test123!"}'

# Login
curl -X POST http://localhost:8000/api/users/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123!"}'

# Get Recipes
curl http://localhost:8000/api/recipes/
📊 Database Schema
Tables
Table	Description
users_user	User accounts
recipes_recipe	Recipe data
recipes_category	Recipe categories
reviews_review	User reviews
favorites_favorite	User favorites
submissions_recipesubmission	Recipe submissions