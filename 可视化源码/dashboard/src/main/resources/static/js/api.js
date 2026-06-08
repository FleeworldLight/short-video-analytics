const API_BASE = '/api';

export async function fetchCompletionByCategory() {
    const res = await axios.get(`${API_BASE}/completion/category`);
    return res.data;
}

export async function fetchRetention() {
    const res = await axios.get(`${API_BASE}/retention`);
    return res.data;
}

export async function fetchHotRanking() {
    const res = await axios.get(`${API_BASE}/hot-ranking`);
    return res.data;
}

export async function fetchInfluencer() {
    const res = await axios.get(`${API_BASE}/influencer`);
    return res.data;
}

export async function fetchTimePeriod() {
    const res = await axios.get(`${API_BASE}/time-period`);
    return res.data;
}

export async function fetchCompletionByAuthor() {
    const res = await axios.get(`${API_BASE}/completion/author`);
    return res.data;
}
