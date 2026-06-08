package com.shortvideo.dashboard.model;

public class ContentHotRanking {
    private Integer rankNo;
    private Integer videoId;
    private Double hotScore;
    private String dt;

    public Integer getRankNo() { return rankNo; }
    public void setRankNo(Integer rankNo) { this.rankNo = rankNo; }
    public Integer getVideoId() { return videoId; }
    public void setVideoId(Integer videoId) { this.videoId = videoId; }
    public Double getHotScore() { return hotScore; }
    public void setHotScore(Double hotScore) { this.hotScore = hotScore; }
    public String getDt() { return dt; }
    public void setDt(String dt) { this.dt = dt; }
}
