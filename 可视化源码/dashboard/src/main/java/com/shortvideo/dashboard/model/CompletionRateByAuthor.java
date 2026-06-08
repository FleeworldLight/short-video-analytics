package com.shortvideo.dashboard.model;

public class CompletionRateByAuthor {
    private Integer uploaderId;
    private Long totalPlays;
    private Double avgCompletionRate;

    public Integer getUploaderId() { return uploaderId; }
    public void setUploaderId(Integer uploaderId) { this.uploaderId = uploaderId; }
    public Long getTotalPlays() { return totalPlays; }
    public void setTotalPlays(Long totalPlays) { this.totalPlays = totalPlays; }
    public Double getAvgCompletionRate() { return avgCompletionRate; }
    public void setAvgCompletionRate(Double avgCompletionRate) { this.avgCompletionRate = avgCompletionRate; }
}
