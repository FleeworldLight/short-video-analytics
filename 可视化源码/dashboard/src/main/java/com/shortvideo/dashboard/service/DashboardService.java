package com.shortvideo.dashboard.service;

import com.shortvideo.dashboard.model.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class DashboardService {

    private final List<CompletionRateByCategory> completionCategory;
    private final List<CompletionRateByAuthor> completionAuthor;
    private final List<UserRetention> retention;
    private final List<ContentHotRanking> hotRanking;
    private final List<InfluencerIndex> influencer;
    private final List<TimePeriodAnalysis> timePeriod;

    public DashboardService(@Value("${app.data-path}") String dataPath) {
        String base = Paths.get(System.getProperty("user.dir"), dataPath).normalize().toString();
        this.completionCategory = readCsv(base + "/completion_rate_by_category.csv", this::mapCompletionCategory);
        this.completionAuthor = readCsv(base + "/completion_rate_by_author.csv", this::mapCompletionAuthor);
        this.retention = readCsv(base + "/retention.csv", this::mapRetention);
        this.hotRanking = readCsv(base + "/hot_ranking.csv", this::mapHotRanking);
        this.influencer = readCsv(base + "/influencer.csv", this::mapInfluencer);
        this.timePeriod = readCsv(base + "/time_period_analysis.csv", this::mapTimePeriod);
    }

    private <T> List<T> readCsv(String path, Function<String[], T> mapper) {
        try {
            return Files.readAllLines(Paths.get(path))
                    .stream()
                    .skip(1)
                    .filter(l -> !l.isBlank())
                    .map(l -> l.split(",", -1))
                    .map(mapper)
                    .collect(Collectors.toList());
        } catch (IOException e) {
            System.err.println("Cannot read " + path + ": " + e.getMessage());
            return List.of();
        }
    }

    private CompletionRateByCategory mapCompletionCategory(String[] c) {
        CompletionRateByCategory o = new CompletionRateByCategory();
        o.setTagName(c[0]);
        o.setTotalPlays(Long.parseLong(c[1]));
        o.setTotalCompletions(Long.parseLong(c[2]));
        o.setCompletionRate(Double.parseDouble(c[3]));
        return o;
    }

    private CompletionRateByAuthor mapCompletionAuthor(String[] c) {
        CompletionRateByAuthor o = new CompletionRateByAuthor();
        o.setUploaderId(Integer.parseInt(c[0]));
        o.setTotalPlays(Long.parseLong(c[1]));
        o.setAvgCompletionRate(Double.parseDouble(c[2]));
        return o;
    }

    private UserRetention mapRetention(String[] c) {
        UserRetention o = new UserRetention();
        o.setReportDate(c[0]);
        o.setDau(Long.parseLong(c[1]));
        o.setDay1Retention(Double.parseDouble(c[2]));
        o.setDay7Retention(Double.parseDouble(c[3]));
        o.setDay30Retention(Double.parseDouble(c[4]));
        return o;
    }

    private ContentHotRanking mapHotRanking(String[] c) {
        ContentHotRanking o = new ContentHotRanking();
        o.setRankNo(Integer.parseInt(c[0]));
        o.setVideoId(Integer.parseInt(c[1]));
        o.setHotScore(Double.parseDouble(c[2]));
        o.setDt(c[3]);
        return o;
    }

    private InfluencerIndex mapInfluencer(String[] c) {
        InfluencerIndex o = new InfluencerIndex();
        o.setRankNo(Integer.parseInt(c[0]));
        o.setUploaderId(Integer.parseInt(c[1]));
        o.setTotalPlays(Long.parseLong(c[2]));
        o.setAvgCompletion(Double.parseDouble(c[3]));
        o.setAvgInteraction(Double.parseDouble(c[4]));
        o.setInfluenceScore(Double.parseDouble(c[5]));
        return o;
    }

    private TimePeriodAnalysis mapTimePeriod(String[] c) {
        TimePeriodAnalysis o = new TimePeriodAnalysis();
        o.setTimePeriod(c[0]);
        o.setPlayCount(Long.parseLong(c[1]));
        o.setAvgWatchRatio(Double.parseDouble(c[2]));
        o.setLikeCount(Long.parseLong(c[3]));
        return o;
    }

    public List<CompletionRateByCategory> getCompletionByCategory() { return completionCategory; }
    public List<CompletionRateByAuthor> getCompletionByAuthor() { return completionAuthor; }
    public List<UserRetention> getRetention() { return retention; }
    public List<ContentHotRanking> getHotRanking() { return hotRanking; }
    public List<InfluencerIndex> getInfluencer() { return influencer; }
    public List<TimePeriodAnalysis> getTimePeriod() { return timePeriod; }
}
