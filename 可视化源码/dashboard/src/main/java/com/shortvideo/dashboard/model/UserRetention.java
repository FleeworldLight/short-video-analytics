package com.shortvideo.dashboard.model;

public class UserRetention {
    private String reportDate;
    private Long dau;
    private Double day1Retention;
    private Double day7Retention;
    private Double day30Retention;

    public String getReportDate() { return reportDate; }
    public void setReportDate(String reportDate) { this.reportDate = reportDate; }
    public Long getDau() { return dau; }
    public void setDau(Long dau) { this.dau = dau; }
    public Double getDay1Retention() { return day1Retention; }
    public void setDay1Retention(Double day1Retention) { this.day1Retention = day1Retention; }
    public Double getDay7Retention() { return day7Retention; }
    public void setDay7Retention(Double day7Retention) { this.day7Retention = day7Retention; }
    public Double getDay30Retention() { return day30Retention; }
    public void setDay30Retention(Double day30Retention) { this.day30Retention = day30Retention; }
}
