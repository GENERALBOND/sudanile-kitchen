import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Sudanile Kitchen'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange.shade400, Colors.orange.shade800],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.restaurant_menu, size: 60, color: Colors.orange),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sudanile Kitchen',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Preserving South Sudanese Culinary Heritage',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Mission Section
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Sudanile Kitchen is dedicated to documenting, preserving, and promoting '
                    'the rich culinary heritage of South Sudan. We believe that food is not just '
                    'sustenance—it is a bridge to our culture, history, and identity.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
            
            // Stats Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('50+', 'Recipes'),
                  Container(height: 40, width: 1, color: Colors.grey.shade300),
                  _buildStat('1000+', 'Users'),
                  Container(height: 40, width: 1, color: Colors.grey.shade300),
                  _buildStat('5', 'Categories'),
                ],
              ),
            ),
            
            // Features Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Features',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.restaurant,
                    'Authentic Recipes',
                    'Traditional South Sudanese recipes passed down through generations',
                  ),
                  _buildFeatureItem(
                    Icons.search,
                    'Smart Search',
                    'Search by ingredients, name, or category',
                  ),
                  _buildFeatureItem(
                    Icons.favorite,
                    'Save Favorites',
                    'Build your personal recipe collection',
                  ),
                  _buildFeatureItem(
                    Icons.rate_review,
                    'Rate & Review',
                    'Share your experience with the community',
                  ),
                  _buildFeatureItem(
                    Icons.add_box,
                    'Submit Recipes',
                    'Contribute your family recipes to preserve heritage',
                  ),
                  _buildFeatureItem(
                    Icons.video_library,
                    'Video Tutorials',
                    'Step-by-step cooking guides',
                  ),
                ],
              ),
            ),
            
            // Team Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Our Team',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTeamMember(
                    'Sudanile Kitchen Team',
                    'Culinary Heritage Preservation',
                    'Dedicated to documenting and sharing South Sudanese cuisine', 
                  ),
                ],
              ),
            ),
            
            // Connect Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Connect With Us',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(Icons.email, 'Email', () async {
                        final Uri emailUri = Uri(
                          scheme: 'mailto',
                          path: 'support@sudanile.com',
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      }),
                      _buildSocialButton(Icons.public, 'Website', () async {
                        final Uri url = Uri.parse('https://sudanile.com');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }),
                      _buildSocialButton(Icons.facebook, 'Facebook', () async {
                        final Uri url = Uri.parse('https://facebook.com/sudanile');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }),
                      _buildSocialButton(Icons.camera_alt, 'Instagram', () async {
                        final Uri url = Uri.parse('https://instagram.com/sudanile');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }),
                    ],
                  ),
                ],
              ),
            ),
            
            // Version Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 Sudanile Kitchen. All rights reserved.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange.shade800, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(String name, String role, String bio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange.shade200,
            child: Text(name[0], style: const TextStyle(fontSize: 24, color: Colors.orange)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(role, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(bio, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.orange, size: 30),
          onPressed: onPressed,
        ),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
