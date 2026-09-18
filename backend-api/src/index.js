export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Admin-API-Key, Authorization',
    };

    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const json = (data, status = 200) => {
      return new Response(JSON.stringify(data), {
        status,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      });
    };

    // Helper for Admin Auth
    const isAuthorized = () => {
      const apiKey = request.headers.get('X-Admin-API-Key');
      const expectedKey = env.ADMIN_API_KEY || 'default_admin_secret';
      return apiKey && apiKey === expectedKey;
    };

    try {
      // PUBLIC ENDPOINTS

      // GET /api/animes
      if (pathname === '/api/animes' && method === 'GET') {
        const { results } = await env.DB.prepare('SELECT * FROM animes ORDER BY id DESC').all();
        return json({ success: true, data: results });
      }

      // GET /api/animes/:id
      const animeMatch = pathname.match(/^\/api\/animes\/(\d+)$/);
      if (animeMatch && method === 'GET') {
        const id = animeMatch[1];
        const anime = await env.DB.prepare('SELECT * FROM animes WHERE id = ?').bind(id).first();
        if (!anime) return json({ success: false, error: 'Anime not found' }, 404);
        return json({ success: true, data: anime });
      }

      // GET /api/episodes/:anime_id
      const epMatch = pathname.match(/^\/api\/episodes\/(\d+)$/);
      if (epMatch && method === 'GET') {
        const animeId = epMatch[1];
        const { results } = await env.DB.prepare(
          'SELECT * FROM episodes WHERE anime_id = ? ORDER BY episode_number ASC'
        ).bind(animeId).all();
        return json({ success: true, data: results });
      }

      // ADMIN ENDPOINTS

      // POST /api/animes
      if (pathname === '/api/animes' && method === 'POST') {
        if (!isAuthorized()) return json({ success: false, error: 'Unauthorized' }, 401);
        const body = await request.json();
        const { title, description, cover_url, status } = body;
        if (!title) return json({ success: false, error: 'Title is required' }, 400);

        const res = await env.DB.prepare(
          'INSERT INTO animes (title, description, cover_url, status) VALUES (?, ?, ?, ?)'
        ).bind(title, description || '', cover_url || '', status || 'Ongoing').run();

        return json({ success: true, id: res.meta.last_row_id }, 201);
      }

      // PUT /api/animes/:id
      if (animeMatch && method === 'PUT') {
        if (!isAuthorized()) return json({ success: false, error: 'Unauthorized' }, 401);
        const id = animeMatch[1];
        const body = await request.json();
        const { title, description, cover_url, status } = body;

        await env.DB.prepare(
          'UPDATE animes SET title = ?, description = ?, cover_url = ?, status = ? WHERE id = ?'
        ).bind(title, description, cover_url, status, id).run();

        return json({ success: true, message: 'Anime updated' });
      }

      // DELETE /api/animes/:id
      if (animeMatch && method === 'DELETE') {
        if (!isAuthorized()) return json({ success: false, error: 'Unauthorized' }, 401);
        const id = animeMatch[1];
        await env.DB.prepare('DELETE FROM episodes WHERE anime_id = ?').bind(id).run();
        await env.DB.prepare('DELETE FROM animes WHERE id = ?').bind(id).run();
        return json({ success: true, message: 'Anime deleted' });
      }

      // POST /api/episodes
      if (pathname === '/api/episodes' && method === 'POST') {
        if (!isAuthorized()) return json({ success: false, error: 'Unauthorized' }, 401);
        const body = await request.json();
        const { anime_id, episode_number, title, video_url } = body;
        if (!anime_id || !episode_number || !video_url) {
          return json({ success: false, error: 'anime_id, episode_number, and video_url required' }, 400);
        }

        const res = await env.DB.prepare(
          'INSERT INTO episodes (anime_id, episode_number, title, video_url) VALUES (?, ?, ?, ?)'
        ).bind(anime_id, episode_number, title || `Episode ${episode_number}`, video_url).run();

        return json({ success: true, id: res.meta.last_row_id }, 201);
      }

      // DELETE /api/episodes/:id
      const epDeleteMatch = pathname.match(/^\/api\/episodes\/delete\/(\d+)$/);
      if (epDeleteMatch && method === 'DELETE') {
        if (!isAuthorized()) return json({ success: false, error: 'Unauthorized' }, 401);
        const epId = epDeleteMatch[1];
        await env.DB.prepare('DELETE FROM episodes WHERE id = ?').bind(epId).run();
        return json({ success: true, message: 'Episode deleted' });
      }

      return json({ success: false, error: 'Endpoint not found' }, 404);
    } catch (err) {
      return json({ success: false, error: err.message }, 500);
    }
  },
};
