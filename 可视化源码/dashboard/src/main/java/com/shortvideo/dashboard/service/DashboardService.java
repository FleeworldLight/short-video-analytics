package com.shortvideo.dashboard.service;

import com.shortvideo.dashboard.model.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

@Service
public class DashboardService {

    @Autowired
    private JdbcTemplate jdbc;

    public List<CompletionRateByCategory> getCompletionByCategory() {
        return jdbc.query("SELECT tag_name, total_plays, total_completions, completion_rate FROM ads_completion_rate_by_category ORDER BY completion_rate DESC", (rs, rowNum) -> {
            CompletionRateByCategory o = new CompletionRateByCategory();
            o.setTagName(rs.getString("tag_name"));
            o.setTotalPlays(rs.getLong("total_plays"));
            o.setTotalCompletions(rs.getLong("total_completions"));
            o.setCompletionRate(rs.getDouble("completion_rate"));
            return o;
        });
    }

    public List<CompletionRateByAuthor> getCompletionByAuthor() {
        return jdbc.query("SELECT uploader_id, total_plays, avg_completion_rate FROM ads_completion_rate_by_author ORDER BY avg_completion_rate DESC", (rs, rowNum) -> {
            CompletionRateByAuthor o = new CompletionRateByAuthor();
            o.setUploaderId(rs.getInt("uploader_id"));
            o.setTotalPlays(rs.getLong("total_plays"));
            o.setAvgCompletionRate(rs.getDouble("avg_completion_rate"));
            return o;
        });
    }

    public List<UserRetention> getRetention() {
        return jdbc.query("SELECT report_date, dau, day1_retention, day7_retention, day30_retention FROM ads_user_retention ORDER BY report_date", (rs, rowNum) -> {
            UserRetention o = new UserRetention();
            o.setReportDate(rs.getString("report_date"));
            o.setDau(rs.getLong("dau"));
            o.setDay1Retention(rs.getDouble("day1_retention"));
            o.setDay7Retention(rs.getDouble("day7_retention"));
            o.setDay30Retention(rs.getDouble("day30_retention"));
            return o;
        });
    }

    public List<ContentHotRanking> getHotRanking() {
        return jdbc.query("SELECT rank_no, video_id, hot_score, dt FROM ads_content_hot_ranking ORDER BY rank_no", (rs, rowNum) -> {
            ContentHotRanking o = new ContentHotRanking();
            o.setRankNo(rs.getInt("rank_no"));
            o.setVideoId(rs.getInt("video_id"));
            o.setHotScore(rs.getDouble("hot_score"));
            o.setDt(rs.getString("dt"));
            return o;
        });
    }

    public List<InfluencerIndex> getInfluencer() {
        return jdbc.query("SELECT rank_no, uploader_id, total_plays, avg_completion, avg_interaction, influence_score FROM ads_influencer_index ORDER BY rank_no", (rs, rowNum) -> {
            InfluencerIndex o = new InfluencerIndex();
            o.setRankNo(rs.getInt("rank_no"));
            o.setUploaderId(rs.getInt("uploader_id"));
            o.setTotalPlays(rs.getLong("total_plays"));
            o.setAvgCompletion(rs.getDouble("avg_completion"));
            o.setAvgInteraction(rs.getDouble("avg_interaction"));
            o.setInfluenceScore(rs.getDouble("influence_score"));
            return o;
        });
    }

    public List<TimePeriodAnalysis> getTimePeriod() {
        return jdbc.query("SELECT time_period, play_count, avg_watch_ratio, like_count FROM ads_time_period_analysis ORDER BY play_count DESC", (rs, rowNum) -> {
            TimePeriodAnalysis o = new TimePeriodAnalysis();
            o.setTimePeriod(rs.getString("time_period"));
            o.setPlayCount(rs.getLong("play_count"));
            o.setAvgWatchRatio(rs.getDouble("avg_watch_ratio"));
            o.setLikeCount(rs.getLong("like_count"));
            return o;
        });
    }
}
