import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/owner_posts_bloc.dart';
import '../../domain/entities/owner_post.dart';

/// Owner Dashboard — admin-only page for managing owner posts.
class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({super.key});

  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<OwnerPostsBloc>().add(LoadAllPosts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F16),
      appBar: AppBar(
        title: const Text('Owner Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0F3D2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFC8A951),
        onPressed: () => _showPostForm(context),
        child: const Icon(Icons.add, color: Color(0xFF0A2E1F)),
      ),
      body: BlocConsumer<OwnerPostsBloc, OwnerPostsState>(
        listenWhen: (prev, curr) => prev.formStatus != curr.formStatus,
        listener: (context, state) {
          if (state.formStatus == OwnerPostsStatus.success) {
            Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/owner-dashboard');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Post saved'),
                  backgroundColor: Color(0xFF22C55E)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == OwnerPostsStatus.loading &&
              state.allPosts.isEmpty) {
            return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF22C55E)),
            );
          }

          if (state.allPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text('No posts yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to create your first community post',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: state.allPosts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _PostCard(post: state.allPosts[i]),
          );
        },
      ),
    );
  }

  void _showPostForm(BuildContext context, [OwnerPost? existing]) {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(
        text: existing?.shortDescription ?? '');
    final imageCtrl =
        TextEditingController(text: existing?.imageUrl ?? '');
    final linkCtrl =
        TextEditingController(text: existing?.externalLink ?? '');
    final locationCtrl =
        TextEditingController(text: existing?.location ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F2A1F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  existing == null ? 'New Post' : 'Edit Post',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                _field('Title *', titleCtrl, required: true),
                const SizedBox(height: 16),
                _field('Short Description *', descCtrl,
                    required: true, maxLines: 3),
                const SizedBox(height: 16),
                _field('Image URL', imageCtrl),
                const SizedBox(height: 16),
                _field('External Link', linkCtrl),
                const SizedBox(height: 16),
                _field('Location', locationCtrl),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC8A951),
                      foregroundColor: const Color(0xFF0A2E1F),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final bloc = context.read<OwnerPostsBloc>();
                      if (existing == null) {
                        bloc.add(CreateOwnerPost(
                          title: titleCtrl.text.trim(),
                          shortDescription: descCtrl.text.trim(),
                          imageUrl: imageCtrl.text.trim().isNotEmpty
                              ? imageCtrl.text.trim()
                              : null,
                          externalLink: linkCtrl.text.trim().isNotEmpty
                              ? linkCtrl.text.trim()
                              : null,
                          location: locationCtrl.text.trim().isNotEmpty
                              ? locationCtrl.text.trim()
                              : null,
                        ));
                      } else {
                        bloc.add(UpdateOwnerPost(
                          id: existing.id,
                          data: {
                            'title': titleCtrl.text.trim(),
                            'short_description': descCtrl.text.trim(),
                            if (imageCtrl.text.trim().isNotEmpty)
                              'image_url': imageCtrl.text.trim(),
                            if (linkCtrl.text.trim().isNotEmpty)
                              'external_link': linkCtrl.text.trim(),
                            if (locationCtrl.text.trim().isNotEmpty)
                              'location': locationCtrl.text.trim(),
                          },
                        ));
                      }
                    },
                    child: Text(
                      existing == null ? 'Publish' : 'Save Changes',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFC8A951)),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final OwnerPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: post.isActive
                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  post.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: post.isActive
                        ? const Color(0xFF22C55E)
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.shortDescription,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.location != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  post.location!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _actionBtn(Icons.edit_rounded, 'Edit', () {
                final page = context
                    .findAncestorStateOfType<_OwnerDashboardPageState>();
                page?._showPostForm(context, post);
              }),
              const SizedBox(width: 12),
              _actionBtn(Icons.delete_outline_rounded, 'Delete', () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF0F2A1F),
                    title: const Text('Delete Post',
                        style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure?',
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context
                              .read<OwnerPostsBloc>()
                              .add(DeleteOwnerPost(post.id));
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }, isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
