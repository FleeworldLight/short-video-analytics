package com.shortvideo.dashboard.controller;

import com.shortvideo.dashboard.model.*;
import com.shortvideo.dashboard.service.DashboardService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin
public class DashboardController {

    @Autowired
    private DashboardService dashboardService;

    @GetMapping("/completion/category")
    public List<CompletionRateByCategory> getCompletionByCategory() {
        return dashboardService.getCompletionByCategory();
    }

    @GetMapping("/completion/author")
    public List<CompletionRateByAuthor> getCompletionByAuthor() {
        return dashboardService.getCompletionByAuthor();
    }

    @GetMapping("/retention")
    public List<UserRetention> getRetention() {
        return dashboardService.getRetention();
    }

    @GetMapping("/hot-ranking")
    public List<ContentHotRanking> getHotRanking() {
        return dashboardService.getHotRanking();
    }

    @GetMapping("/influencer")
    public List<InfluencerIndex> getInfluencer() {
        return dashboardService.getInfluencer();
    }

    @GetMapping("/time-period")
    public List<TimePeriodAnalysis> getTimePeriod() {
        return dashboardService.getTimePeriod();
    }
}
