package com.shortvideo.dashboard.model;

public class CompletionRateByCategory {
    private String tagName;
    private Long totalPlays;
    private Long totalCompletions;
    private Double completionRate;

    public String getTagName() { return tagName; }
    public void setTagName(String tagName) { this.tagName = tagName; }
    public Long getTotalPlays() { return totalPlays; }
    public void setTotalPlays(Long totalPlays) { this.totalPlays = totalPlays; }
    public Long getTotalCompletions() { return totalCompletions; }
    public void setTotalCompletions(Long totalCompletions) { this.totalCompletions = totalCompletions; }
    public Double getCompletionRate() { return completionRate; }
    public void setCompletionRate(Double completionRate) { this.completionRate = completionRate; }
}
