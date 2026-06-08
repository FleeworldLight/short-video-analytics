package com.shortvideo.dashboard.model;

public class InfluencerIndex {
    private Integer rankNo;
    private Integer uploaderId;
    private Long totalPlays;
    private Double avgCompletion;
    private Double avgInteraction;
    private Double influenceScore;

    public Integer getRankNo() { return rankNo; }
    public void setRankNo(Integer rankNo) { this.rankNo = rankNo; }
    public Integer getUploaderId() { return uploaderId; }
    public void setUploaderId(Integer uploaderId) { this.uploaderId = uploaderId; }
    public Long getTotalPlays() { return totalPlays; }
    public void setTotalPlays(Long totalPlays) { this.totalPlays = totalPlays; }
    public Double getAvgCompletion() { return avgCompletion; }
    public void setAvgCompletion(Double avgCompletion) { this.avgCompletion = avgCompletion; }
    public Double getAvgInteraction() { return avgInteraction; }
    public void setAvgInteraction(Double avgInteraction) { this.avgInteraction = avgInteraction; }
    public Double getInfluenceScore() { return influenceScore; }
    public void setInfluenceScore(Double influenceScore) { this.influenceScore = influenceScore; }
}
