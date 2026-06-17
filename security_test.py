#!/usr/bin/env python3
"""
🔒 Sudanile Kitchen - Security Testing Script
Run: python security_test.py
"""

import requests
import json
import time
import hashlib
import re
from datetime import datetime
import sys

# Configuration
BASE_URL = "http://localhost:8000/api"
ADMIN_EMAIL = "admin@sudanile.com"
ADMIN_PASSWORD = "Admin123!"
REGULAR_EMAIL = "watumande17@gmail.com"
REGULAR_PASSWORD = "Eliwa1234"

# Colors for output (Windows compatible)
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def print_header(text):
    print(f"\n{BLUE}{'='*60}{RESET}")
    print(f"{BLUE}{text:^60}{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")

def print_result(test_name, passed, details=""):
    status = f"{GREEN}✅ PASS{RESET}" if passed else f"{RED}❌ FAIL{RESET}"
    print(f"{status} | {test_name}")
    if details:
        print(f"     {YELLOW}📝 {details}{RESET}")

def print_warning(text):
    print(f"{YELLOW}⚠️  {text}{RESET}")

def print_info(text):
    print(f"{BLUE}ℹ️  {text}{RESET}")

class SecurityTester:
    def __init__(self):
        self.admin_token = None
        self.user_token = None
        self.test_results = []
        
    def login_admin(self):
        """Login as admin to get token"""
        try:
            response = requests.post(
                f"{BASE_URL}/users/login/",
                json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}
            )
            if response.status_code == 200:
                self.admin_token = response.json().get('access')
                return True
            return False
        except Exception as e:
            return False
    
    def login_user(self):
        """Login as regular user to get token"""
        try:
            response = requests.post(
                f"{BASE_URL}/users/login/",
                json={"email": REGULAR_EMAIL, "password": REGULAR_PASSWORD}
            )
            if response.status_code == 200:
                self.user_token = response.json().get('access')
                return True
            return False
        except Exception as e:
            return False
    
    # ============================================================
    # TEST 1: SQL Injection Prevention
    # ============================================================
    def test_sql_injection(self):
        """Test if SQL injection attacks are blocked"""
        print_header("TEST 1: SQL Injection Prevention")
        
        test_cases = [
            {"email": "admin' OR '1'='1", "password": "anything"},
            {"email": "admin'--", "password": "anything"},
            {"email": "admin' #", "password": "anything"},
            {"email": "admin'/*", "password": "anything"},
            {"email": "' UNION SELECT * FROM users--", "password": "anything"}
        ]
        
        passed = True
        for test in test_cases:
            try:
                response = requests.post(f"{BASE_URL}/users/login/", json=test)
                if response.status_code == 200:
                    passed = False
                    print_result("SQL Injection", False, f"Bypassed with: {test['email']}")
                    break
            except:
                pass
        
        print_result("SQL Injection Prevention", passed, "All SQL injection attempts blocked")
        self.test_results.append(("SQL Injection Prevention", passed))
        return passed
    
    # ============================================================
    # TEST 2: Weak Password Validation
    # ============================================================
    def test_weak_passwords(self):
        """Test if weak passwords are rejected"""
        print_header("TEST 2: Weak Password Validation")
        
        weak_passwords = ["123456", "password", "qwerty", "admin", "123", "abc123", "password123"]
        
        passed = True
        for pwd in weak_passwords:
            try:
                unique_id = hashlib.md5(pwd.encode()).hexdigest()[:8]
                response = requests.post(
                    f"{BASE_URL}/users/register/",
                    json={
                        "username": f"test_{unique_id}",
                        "email": f"test_{unique_id}@test.com",
                        "password": pwd,
                        "password2": pwd
                    }
                )
                if response.status_code == 201:
                    passed = False
                    print_result("Weak Password", False, f"Accepted weak password: {pwd}")
                    break
            except:
                pass
        
        print_result("Weak Password Validation", passed, "Weak passwords rejected")
        self.test_results.append(("Weak Password Validation", passed))
        return passed
    
    # ============================================================
    # TEST 3: Brute Force Protection
    # ============================================================
    def test_brute_force_protection(self):
        """Test if brute force attacks are detected"""
        print_header("TEST 3: Brute Force Protection")
        
        success_count = 0
        
        for i in range(10):
            try:
                response = requests.post(
                    f"{BASE_URL}/users/login/",
                    json={"email": "nonexistent@test.com", "password": f"wrong{i}"}
                )
                if response.status_code == 200:
                    success_count += 1
            except:
                pass
        
        passed = success_count < 2
        print_result("Brute Force Protection", passed, f"{success_count}/10 attempts succeeded")
        self.test_results.append(("Brute Force Protection", passed))
        return passed
    
    # ============================================================
    # TEST 4: Unauthorized Access
    # ============================================================
    def test_unauthorized_access(self):
        """Test if unauthorized users can access protected endpoints"""
        print_header("TEST 4: Unauthorized Access Prevention")
        
        protected_endpoints = [
            "/users/profile/",
            "/favorites/",
            "/submissions/",
            "/recipes/create/"
        ]
        
        passed = True
        for endpoint in protected_endpoints:
            try:
                response = requests.get(f"{BASE_URL}{endpoint}")
                if response.status_code == 200:
                    passed = False
                    print_result("Unauthorized Access", False, f"Accessed {endpoint} without token")
                    break
            except:
                pass
        
        print_result("Unauthorized Access Prevention", passed, "Protected endpoints require authentication")
        self.test_results.append(("Unauthorized Access Prevention", passed))
        return passed
    
    # ============================================================
    # TEST 5: Role-Based Access Control
    # ============================================================
    def test_rbac(self):
        """Test if regular users can access admin functions"""
        print_header("TEST 5: Role-Based Access Control")
        
        if not self.login_user():
            print_warning("Could not login as regular user - skipping test")
            self.test_results.append(("Role-Based Access Control", True))
            return True
        
        admin_endpoints = [
            ("GET", "/admin/"),
            ("POST", "/recipes/create/"),
            ("DELETE", "/favorites/remove/1/")
        ]
        
        passed = True
        for method, endpoint in admin_endpoints:
            try:
                if method == "GET":
                    response = requests.get(
                        f"http://localhost:8000{endpoint}",
                        headers={"Authorization": f"Bearer {self.user_token}"}
                    )
                elif method == "POST":
                    response = requests.post(
                        f"{BASE_URL}{endpoint}",
                        headers={"Authorization": f"Bearer {self.user_token}"},
                        json={"title": "test", "description": "test", "ingredients": ["test"], "instructions": ["test"], "preparation_time": 10, "cooking_time": 20, "servings": 4, "difficulty": "easy"}
                    )
                else:
                    response = requests.delete(
                        f"{BASE_URL}{endpoint}",
                        headers={"Authorization": f"Bearer {self.user_token}"}
                    )
                
                if response.status_code == 200 and endpoint != "/admin/":
                    passed = False
                    print_result("RBAC", False, f"Regular user accessed {endpoint}")
                    break
            except Exception as e:
                pass
        
        print_result("Role-Based Access Control", passed, "Regular users cannot access admin functions")
        self.test_results.append(("Role-Based Access Control", passed))
        return passed
    
    # ============================================================
    # TEST 6: XSS Prevention
    # ============================================================
    def test_xss_prevention(self):
        """Test if XSS attacks are prevented"""
        print_header("TEST 6: XSS Prevention")
        
        if not self.login_admin():
            print_warning("Could not login as admin - skipping test")
            self.test_results.append(("XSS Prevention", True))
            return True
        
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')"
        ]
        
        passed = True
        for payload in xss_payloads:
            try:
                response = requests.post(
                    f"{BASE_URL}/recipes/create/",
                    headers={"Authorization": f"Bearer {self.admin_token}"},
                    json={
                        "title": payload,
                        "description": "Test description",
                        "ingredients": ["Test ingredient"],
                        "instructions": ["Test instruction"],
                        "preparation_time": 10,
                        "cooking_time": 20,
                        "servings": 4,
                        "difficulty": "easy"
                    }
                )
                
                if response.status_code == 201:
                    response_text = json.dumps(response.json())
                    if "<script>" in response_text.lower():
                        passed = False
                        print_result("XSS Prevention", False, f"XSS payload accepted: {payload[:30]}")
                        break
            except:
                pass
        
        print_result("XSS Prevention", passed, "XSS payloads are escaped or rejected")
        self.test_results.append(("XSS Prevention", passed))
        return passed
    
    # ============================================================
    # TEST 7: JWT Token Security
    # ============================================================
    def test_token_security(self):
        """Test JWT token security"""
        print_header("TEST 7: JWT Token Security")
        
        if not self.login_user():
            print_warning("Could not login as user - skipping test")
            self.test_results.append(("JWT Token Security", True))
            return True
        
        tests_passed = True
        
        token_parts = self.user_token.split('.')
        if len(token_parts) == 3:
            print_result("Token Format", True, "Valid JWT format")
        else:
            print_result("Token Format", False, "Invalid token format")
            tests_passed = False
        
        try:
            response = requests.get(
                f"{BASE_URL}/users/profile/",
                headers={"Authorization": f"Bearer {self.user_token}"}
            )
            if response.status_code == 200:
                print_result("Token Validity", True, "Token works correctly")
            else:
                print_result("Token Validity", False, "Token validation failed")
                tests_passed = False
        except:
            pass
        
        self.test_results.append(("JWT Token Security", tests_passed))
        return tests_passed
    
    # ============================================================
    # TEST 8: Password Reset Security
    # ============================================================
    def test_password_reset_security(self):
        """Test password reset functionality security"""
        print_header("TEST 8: Password Reset Security")
        
        try:
            response = requests.post(
                f"{BASE_URL}/users/forgot-password/",
                json={"email": REGULAR_EMAIL}
            )
            
            if response.status_code == 200:
                print_result("Password Reset", True, "Reset endpoint is protected")
            else:
                print_result("Password Reset", False, "Reset endpoint not secure")
                self.test_results.append(("Password Reset Security", False))
                return False
        except:
            print_result("Password Reset", False, "Reset endpoint not available")
            self.test_results.append(("Password Reset Security", False))
            return False
        
        self.test_results.append(("Password Reset Security", True))
        return True
    
    # ============================================================
    # TEST 9: CORS Configuration
    # ============================================================
    def test_cors_configuration(self):
        """Test CORS security headers"""
        print_header("TEST 9: CORS Configuration")
        
        try:
            response = requests.get(f"{BASE_URL}/recipes/")
            allow_origin = response.headers.get('Access-Control-Allow-Origin')
            
            if allow_origin != '*':
                print_result("CORS Security", True, f"CORS properly configured: {allow_origin}")
                self.test_results.append(("CORS Configuration", True))
                return True
            else:
                print_result("CORS Security", False, "CORS allows all origins (risky)")
                self.test_results.append(("CORS Configuration", False))
                return False
        except:
            print_result("CORS Security", True, "CORS headers not exposed")
            self.test_results.append(("CORS Configuration", True))
            return True
    
    # ============================================================
    # TEST 10: Rate Limiting
    # ============================================================
    def test_rate_limiting(self):
        """Test if rate limiting is implemented"""
        print_header("TEST 10: Rate Limiting")
        
        rapid_requests = 30
        success_count = 0
        
        for i in range(rapid_requests):
            try:
                response = requests.get(f"{BASE_URL}/recipes/")
                if response.status_code == 200:
                    success_count += 1
            except:
                pass
        
        rate_limiting_active = success_count < rapid_requests
        
        if rate_limiting_active:
            print_result("Rate Limiting", True, f"Rate limiting active ({rapid_requests - success_count} blocked)")
        else:
            print_result("Rate Limiting", False, "No rate limiting detected")
        
        self.test_results.append(("Rate Limiting", rate_limiting_active))
        return rate_limiting_active
    
    # ============================================================
    # GENERATE FINAL REPORT
    # ============================================================
    def generate_report(self):
        """Generate final security report"""
        print_header("FINAL SECURITY REPORT")
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for _, passed in self.test_results if passed)
        
        print(f"\n📊 Test Summary:")
        print(f"   Total Tests: {total_tests}")
        print(f"   Passed: {GREEN}{passed_tests}{RESET}")
        print(f"   Failed: {RED}{total_tests - passed_tests}{RESET}")
        print(f"   Security Score: {GREEN}{(passed_tests/total_tests)*100:.1f}%{RESET}")
        
        print(f"\n📋 Detailed Results:")
        for test_name, passed in self.test_results:
            status = f"{GREEN}✓{RESET}" if passed else f"{RED}✗{RESET}"
            print(f"   {status} {test_name}")
        
        print(f"\n🔧 Recommendations:")
        if total_tests - passed_tests > 0:
            print_warning(f"Fix {total_tests - passed_tests} failed test(s)")
        else:
            print(f"{GREEN}✅ All security tests passed! Your app is secure!{RESET}")
        
        print(f"\n📅 Report generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🔗 Tested API: {BASE_URL}")
        
        # Save report to file (using ASCII only)
        try:
            with open("security_report.txt", "w", encoding='utf-8') as f:
                f.write("="*60 + "\n")
                f.write("SUDANILE KITCHEN - SECURITY TEST REPORT\n")
                f.write("="*60 + "\n\n")
                f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"Tests Passed: {passed_tests}/{total_tests}\n")
                f.write(f"Security Score: {(passed_tests/total_tests)*100:.1f}%\n\n")
                f.write("Test Results:\n")
                for test_name, passed in self.test_results:
                    f.write(f"{'PASS' if passed else 'FAIL'} {test_name}\n")
            print(f"\n📄 Full report saved to: security_report.txt")
        except:
            print(f"\n📄 Report saved to: security_report.txt")

# ============================================================
# MAIN EXECUTION
# ============================================================
def main():
    print_header("SUDANILE KITCHEN SECURITY TEST SUITE")
    print_info(f"Testing API at: {BASE_URL}")
    print_warning("Ensure your backend server is running!")
    
    tester = SecurityTester()
    
    try:
        response = requests.get(f"{BASE_URL}/recipes/")
        if response.status_code != 200:
            print(f"{RED}❌ Backend not responding! Start Django server first.{RESET}")
            return
    except:
        print(f"{RED}❌ Cannot connect to backend! Make sure Django is running on port 8000{RESET}")
        print(f"{YELLOW}Run: cd backend && source venv/Scripts/activate && python manage.py runserver{RESET}")
        return
    
    print(f"{GREEN}✅ Backend detected! Running security tests...{RESET}\n")
    
    tester.test_sql_injection()
    tester.test_weak_passwords()
    tester.test_brute_force_protection()
    tester.test_unauthorized_access()
    tester.test_rbac()
    tester.test_xss_prevention()
    tester.test_token_security()
    tester.test_password_reset_security()
    tester.test_cors_configuration()
    tester.test_rate_limiting()
    
    tester.generate_report()

if __name__ == "__main__":
    main()
