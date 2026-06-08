import * as api from './api.js';

export async function renderCompletionByCategory(domId) {
    const data = await api.fetchCompletionByCategory();
    const chart = echarts.init(document.getElementById(domId));
    chart.setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'category', data: data.map(d => d.tagName), axisLabel: { rotate: 45 } },
        yAxis: { type: 'value', name: '完播率', axisLabel: { formatter: '{value}%' } },
        series: [{ type: 'bar', data: data.map(d => (d.completionRate * 100).toFixed(1)),
            itemStyle: { color: new echarts.graphic.LinearGradient(0,0,0,1,
                [{offset:0,color:'#667eea'},{offset:1,color:'#764ba2'}]) }
        }]
    });
}

export async function renderRetention(domId) {
    const data = await api.fetchRetention();
    const chart = echarts.init(document.getElementById(domId));
    chart.setOption({
        tooltip: { trigger: 'axis' },
        legend: { data: ['次日留存', '7日留存', '30日留存'] },
        xAxis: { type: 'category', data: data.map(d => d.reportDate) },
        yAxis: { type: 'value', name: '留存率', axisLabel: { formatter: '{value}%' } },
        series: [
            { name: '次日留存', type: 'line', data: data.map(d => (d.day1Retention * 100).toFixed(1)), smooth: true },
            { name: '7日留存', type: 'line', data: data.map(d => (d.day7Retention * 100).toFixed(1)), smooth: true },
            { name: '30日留存', type: 'line', data: data.map(d => (d.day30Retention * 100).toFixed(1)), smooth: true }
        ]
    });
}

export async function renderHotRanking(domId) {
    const data = (await api.fetchHotRanking()).slice(0, 30);
    const chart = echarts.init(document.getElementById(domId));
    chart.setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'value', name: '热度分' },
        yAxis: { type: 'category', data: data.map(d => '#' + d.videoId).reverse() },
        series: [{ type: 'bar', data: data.map(d => d.hotScore).reverse(),
            itemStyle: { color: new echarts.graphic.LinearGradient(0,0,1,0,
                [{offset:0,color:'#f09b22'},{offset:1,color:'#f56565'}]) }
        }]
    });
}

export async function renderInfluencer(domId) {
    const data = await api.fetchInfluencer();
    const chart = echarts.init(document.getElementById(domId));
    chart.setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'value', name: '影响力分' },
        yAxis: { type: 'category', data: data.map(d => '创作者' + d.uploaderId).reverse() },
        series: [{ type: 'bar', data: data.map(d => d.influenceScore).reverse(),
            itemStyle: { color: new echarts.graphic.LinearGradient(0,0,1,0,
                [{offset:0,color:'#48bb78'},{offset:1,color:'#38b2ac'}]) }
        }]
    });
}
