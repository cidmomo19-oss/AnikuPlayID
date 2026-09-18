const getApiUrl = () => document.getElementById('apiUrl').value.replace(/\/+$/, '');
const getApiKey = () => document.getElementById('apiKey').value;

let activeAnime = null;

document.addEventListener('DOMContentLoaded', () => {
  fetchAnimes();

  document.getElementById('refreshAnimeBtn').addEventListener('click', fetchAnimes);
  document.getElementById('animeForm').addEventListener('submit', handleAnimeSubmit);
  document.getElementById('cancelEditAnime').addEventListener('click', resetAnimeForm);
  document.getElementById('episodeForm').addEventListener('submit', handleEpisodeSubmit);
});

// Fetch & Render Animes
async function fetchAnimes() {
  const container = document.getElementById('animeList');
  container.innerHTML = '<p class="text-gray-400 text-sm">Memuat data...</p>';

  try {
    const res = await fetch(`${getApiUrl()}/api/animes`);
    const result = await res.json();

    if (!result.success) throw new Error(result.error || 'Gagal memuat anime');

    renderAnimeList(result.data || []);
  } catch (err) {
    container.innerHTML = `<p class="text-red-400 text-sm">Error: ${err.message}</p>`;
  }
}

function renderAnimeList(animes) {
  const container = document.getElementById('animeList');
  if (animes.length === 0) {
    container.innerHTML = '<p class="text-gray-400 text-sm">Belum ada anime. Tambahkan anime di atas.</p>';
    return;
  }

  container.innerHTML = animes.map(anime => `
    <div class="bg-gray-900 p-3 rounded flex items-center justify-between gap-4 border border-gray-800 hover:border-gray-700 transition">
      <div class="flex items-center gap-3 overflow-hidden">
        <img src="${anime.cover_url || 'https://via.placeholder.com/80x110?text=No+Cover'}" alt="${escapeHtml(anime.title)}" class="w-12 h-16 object-cover rounded bg-gray-800 flex-shrink-0">
        <div class="min-w-0">
          <h3 class="font-semibold text-sm text-white truncate">${escapeHtml(anime.title)}</h3>
          <p class="text-xs text-gray-400 truncate">${escapeHtml(anime.description || 'Tidak ada deskripsi')}</p>
          <span class="inline-block mt-1 text-[10px] px-2 py-0.5 rounded ${anime.status === 'Completed' ? 'bg-green-900/60 text-green-300' : 'bg-blue-900/60 text-blue-300'}">${anime.status}</span>
        </div>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <button onclick="selectAnimeForEpisodes(${anime.id}, '${escapeQuote(anime.title)}')" class="bg-blue-600 hover:bg-blue-500 text-xs px-2.5 py-1.5 rounded text-white font-medium">Episode</button>
        <button onclick="editAnime(${anime.id}, '${escapeQuote(anime.title)}', '${escapeQuote(anime.description || '')}', '${escapeQuote(anime.cover_url || '')}', '${anime.status}')" class="bg-gray-700 hover:bg-gray-600 text-xs px-2.5 py-1.5 rounded text-white">Edit</button>
        <button onclick="deleteAnime(${anime.id})" class="bg-red-800 hover:bg-red-700 text-xs px-2.5 py-1.5 rounded text-white">Hapus</button>
      </div>
    </div>
  `).join('');
}

// Anime Form Submit (Add or Edit)
async function handleAnimeSubmit(e) {
  e.preventDefault();

  const id = document.getElementById('animeId').value;
  const title = document.getElementById('animeTitle').value;
  const description = document.getElementById('animeDescription').value;
  const cover_url = document.getElementById('animeCover').value;
  const status = document.getElementById('animeStatus').value;

  const method = id ? 'PUT' : 'POST';
  const endpoint = id ? `${getApiUrl()}/api/animes/${id}` : `${getApiUrl()}/api/animes`;

  try {
    const res = await fetch(endpoint, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Admin-API-Key': getApiKey()
      },
      body: JSON.stringify({ title, description, cover_url, status })
    });

    const result = await res.json();
    if (!result.success) throw new Error(result.error || 'Gagal menyimpan anime');

    resetAnimeForm();
    fetchAnimes();
    alert(id ? 'Anime berhasil diperbarui!' : 'Anime berhasil ditambahkan!');
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

function editAnime(id, title, description, cover_url, status) {
  document.getElementById('animeFormTitle').innerText = 'Edit Anime';
  document.getElementById('animeId').value = id;
  document.getElementById('animeTitle').value = title;
  document.getElementById('animeDescription').value = description;
  document.getElementById('animeCover').value = cover_url;
  document.getElementById('animeStatus').value = status;
  document.getElementById('cancelEditAnime').classList.remove('hidden');
}

function resetAnimeForm() {
  document.getElementById('animeFormTitle').innerText = 'Tambah Anime Baru';
  document.getElementById('animeForm').reset();
  document.getElementById('animeId').value = '';
  document.getElementById('cancelEditAnime').classList.add('hidden');
}

async function deleteAnime(id) {
  if (!confirm('Yakin ingin menghapus anime ini dan seluruh episodenya?')) return;

  try {
    const res = await fetch(`${getApiUrl()}/api/animes/${id}`, {
      method: 'DELETE',
      headers: { 'X-Admin-API-Key': getApiKey() }
    });
    const result = await res.json();
    if (!result.success) throw new Error(result.error || 'Gagal menghapus anime');

    fetchAnimes();
    if (activeAnime && activeAnime.id === id) {
      activeAnime = null;
      document.getElementById('selectedAnimeTitle').innerText = 'Pilih anime dari daftar di samping untuk mengelola episode.';
      document.getElementById('episodeForm').classList.add('hidden');
      document.getElementById('episodeList').innerHTML = '<p class="text-gray-500 text-xs">Belum ada anime dipilih.</p>';
    }
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

// Manage Episodes
function selectAnimeForEpisodes(id, title) {
  activeAnime = { id, title };
  document.getElementById('selectedAnimeTitle').innerText = `Anime Diset: ${title}`;
  document.getElementById('epAnimeId').value = id;
  document.getElementById('episodeForm').classList.remove('hidden');
  fetchEpisodes(id);
}

async function fetchEpisodes(animeId) {
  const container = document.getElementById('episodeList');
  container.innerHTML = '<p class="text-gray-400 text-xs">Memuat episode...</p>';

  try {
    const res = await fetch(`${getApiUrl()}/api/episodes/${animeId}`);
    const result = await res.json();
    if (!result.success) throw new Error(result.error || 'Gagal memuat episode');

    renderEpisodeList(result.data || []);
  } catch (err) {
    container.innerHTML = `<p class="text-red-400 text-xs">Error: ${err.message}</p>`;
  }
}

function renderEpisodeList(episodes) {
  const container = document.getElementById('episodeList');
  if (episodes.length === 0) {
    container.innerHTML = '<p class="text-gray-500 text-xs">Belum ada episode untuk anime ini.</p>';
    return;
  }

  container.innerHTML = episodes.map(ep => `
    <div class="bg-gray-900 p-2.5 rounded border border-gray-800 flex items-center justify-between text-xs">
      <div class="min-w-0 pr-2">
        <span class="font-bold text-red-400">Eps ${ep.episode_number}:</span>
        <span class="text-gray-200 truncate ml-1">${escapeHtml(ep.title || '')}</span>
      </div>
      <button onclick="deleteEpisode(${ep.id})" class="text-red-400 hover:text-red-300 text-xs flex-shrink-0">Hapus</button>
    </div>
  `).join('');
}

async function handleEpisodeSubmit(e) {
  e.preventDefault();

  const anime_id = document.getElementById('epAnimeId').value;
  const episode_number = parseInt(document.getElementById('epNumber').value, 10);
  const title = document.getElementById('epTitle').value;
  const video_url = document.getElementById('epVideoUrl').value;

  try {
    const res = await fetch(`${getApiUrl()}/api/episodes`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Admin-API-Key': getApiKey()
      },
      body: JSON.stringify({ anime_id, episode_number, title, video_url })
    });

    const result = await res.json();
    if (!result.success) throw new Error(result.error || 'Gagal menambah episode');

    document.getElementById('epNumber').value = episode_number + 1;
    document.getElementById('epTitle').value = '';
    document.getElementById('epVideoUrl').value = '';

    fetchEpisodes(anime_id);
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

async function deleteEpisode(epId) {
  if (!confirm('Hapus episode ini?')) return;

  try {
    const res = await fetch(`${getApiUrl()}/api/episodes/delete/${epId}`, {
      method: 'DELETE',
      headers: { 'X-Admin-API-Key': getApiKey() }
    });
    const result = await res.json();
    if (!result.success) throw new Error(result.error || 'Gagal menghapus episode');

    if (activeAnime) fetchEpisodes(activeAnime.id);
  } catch (err) {
    alert(`Error: ${err.message}`);
  }
}

// Helpers
function escapeHtml(str) {
  return String(str || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function escapeQuote(str) {
  return String(str || '').replace(/'/g, "\\'").replace(/"/g, '&quot;');
}
