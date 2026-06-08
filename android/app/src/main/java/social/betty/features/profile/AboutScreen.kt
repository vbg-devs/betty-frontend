package social.betty.features.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import social.betty.designsystem.BettyTheme
import social.betty.designsystem.Palette
import social.betty.designsystem.Space
import social.betty.designsystem.components.BettyScaffold
import social.betty.designsystem.components.InsetPanel
import social.betty.designsystem.components.KickerText
import social.betty.designsystem.components.SurfaceCard

/** Web `/about` rendered natively: hero, WHAT/WHO cards, the three steps, and the tips. */
@Composable
fun AboutScreen() {
    BettyScaffold(modifier = Modifier.testTag("about-screen")) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(Space.m)
                .padding(bottom = Space.xxl),
            verticalArrangement = Arrangement.spacedBy(Space.grid),
        ) {
            Hero()
            WhatCard()
            WhoCard()
            HowSection()
            TipsCard()
        }
    }
}

@Composable
private fun Hero() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    SurfaceCard {
        Column(verticalArrangement = Arrangement.spacedBy(Space.m)) {
            KickerText(text = "★ ABOUT BETTY", color = Palette.orange)
            Column {
                Text(text = "HI, I'M", style = type.displayXL, color = colors.textPrimary)
                Text(text = "BETTY.", style = type.displayXL, color = colors.accentPositive)
            }
            Text(
                text = "I run the bets, count the points, and keep the receipts for tournament " +
                    "predictions between you and your friends. Pick a cup, gather your crew, and " +
                    "let the leaderboard sort out who actually knows their football.",
                style = bodyStyle(),
                color = colors.textBody,
            )
        }
    }
}

@Composable
private fun WhatCard() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    InsetPanel(accent = Palette.orange) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            KickerText(text = "★ WHAT", color = Palette.orange)
            Text(text = "A SOCIAL PREDICTIONS GAME.", style = type.title2, color = colors.textPrimary)
            Text(
                text = "Betty is a free game for tournament predictions. Each group sets its own " +
                    "house rules, everyone bets on exact match results, and points roll in as games " +
                    "go final. No money, no spreadsheets — just bragging rights, settled in public.",
                style = bodyStyle(),
                color = colors.textBody,
            )
        }
    }
}

@Composable
private fun WhoCard() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    InsetPanel(accent = colors.accentPositive) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            KickerText(text = "● WHO", color = colors.accentPositive)
            Text(text = "YOUR SCOREKEEPER.", style = type.title2, color = colors.textPrimary)
            Text(
                text = "Betty was born in Varberg in 2021, out of one too many half-broken Excel " +
                    "sheets and a group chat that wouldn't stop arguing about whether Anna's bet " +
                    "\"really counted.\" She's the bookkeeper, the timekeeper, and the receipts. " +
                    "She handles the math. You handle the banter.",
                style = bodyStyle(),
                color = colors.textBody,
            )
        }
    }
}

@Composable
private fun HowSection() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
        KickerText(text = "★ HOW IT WORKS", color = Palette.orange)
        Text(text = "THREE STEPS. NO FINE PRINT.", style = type.title1, color = colors.textPrimary)
        StepCard(
            kicker = "★ SET",
            kickerColor = Palette.orange,
            number = "01",
            title = "Make a group",
            copy = "Pick a tournament, set your points-per-correct, share one invite link. " +
                "Thirty seconds, tops.",
        )
        StepCard(
            kicker = "● BET",
            kickerColor = colors.accentPositive,
            number = "02",
            title = "Lock the bets",
            copy = "Predict exact scores for every match. Bets close at kickoff — no refunds, " +
                "no edits, no excuses.",
        )
        StepCard(
            kicker = "★ WIN",
            kickerColor = Palette.yellow,
            number = "03",
            title = "Climb the board",
            copy = "Live standings, group chat, a podium for the winner — and a permanent record " +
                "once the tournament wraps.",
        )
    }
}

@Composable
private fun StepCard(
    kicker: String,
    kickerColor: Color,
    number: String,
    title: String,
    copy: String,
) {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    SurfaceCard {
        Column(verticalArrangement = Arrangement.spacedBy(Space.xs)) {
            KickerText(text = kicker, color = kickerColor)
            Text(text = number, style = type.scoreXL, color = colors.textMuted)
            Text(text = title, style = type.title3, color = colors.textPrimary)
            Text(text = copy, style = bodyStyle(), color = colors.textBody)
        }
    }
}

@Composable
private fun TipsCard() {
    val colors = BettyTheme.colors
    val type = BettyTheme.type
    InsetPanel(accent = Palette.yellow) {
        Column(verticalArrangement = Arrangement.spacedBy(Space.s)) {
            KickerText(text = "★ TIPS", color = Palette.orange)
            Text(
                text = "GETTING THE MOST OUT OF BETTY.",
                style = type.title2,
                color = colors.textPrimary,
            )
            TIPS.forEach { (lead, detail) ->
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Space.xs),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text = "★", style = type.kicker, color = Palette.orange)
                    Text(
                        text = boldLead(lead, detail),
                        style = bodyStyle(),
                        color = colors.textBody,
                    )
                }
            }
        }
    }
}

/** Body copy: 15sp medium (iOS `.betty(15, .medium)`). */
@Composable
private fun bodyStyle() = BettyTheme.type.body

/** Bold lead clause + regular detail, mirroring the inline markdown bold in the iOS tips. */
private fun boldLead(lead: String, detail: String) =
    androidx.compose.ui.text.buildAnnotatedString {
        pushStyle(androidx.compose.ui.text.SpanStyle(fontWeight = FontWeight.ExtraBold))
        append(lead)
        pop()
        append(detail)
    }

private val TIPS: List<Pair<String, String>> = listOf(
    "Invite early." to " Bets lock at kickoff, so the sooner the group is full, the more " +
        "matches everyone gets to call.",
    "Set points that match the vibe." to " Bigger exact-score bonuses = more chaos and bigger " +
        "comebacks. Lower bonuses = a slower, steadier race.",
    "Use the group chat." to " The smack-talk is half the point. Betty doesn't judge.",
    "Check the global leaderboard." to " Curious how you stack up beyond your own crew? " +
        "It's right in the menu.",
)
