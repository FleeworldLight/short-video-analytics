package com.shortvideo.dashboard.model;

public class TimePeriodAnalysis {
    private String timePeriod;
    private Long playCount;
    private Double avgWatchRatio;
    private Long likeCount;

    public String getTimePeriod() { return timePeriod; }
    public void setTimePeriod(String timePeriod) { this.timePeriod = timePeriod; }
    public Long getPlayCount() { return playCount; }
    public void setPlayCount(Long playCount) { this.playCount = playCount; }
    public Double getAvgWatchRatio() { return avgWatchRatio; }
    public void setAvgWatchRatio(Double avgWatchRatio) { this.avgWatchRatio = avgWatchRatio; }
    public Long getLikeCount() { return likeCount; }
    public void setLikeCount(Long likeCount) { this.likeCount = likeCount; }
}
