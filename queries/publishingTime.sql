WITH base AS (
    -- Submissions received in 2025 (filtered by date_submitted)
    SELECT s.submission_id, s.date_submitted
    FROM submissions s
    WHERE YEAR(s.date_submitted) = 2025
),

base_published AS (
    -- Articles published in 2025 (filtered by date_published)
    SELECT s.submission_id, s.date_submitted
    FROM submissions s
    INNER JOIN publications p ON p.submission_id = s.submission_id AND p.status = 3
    WHERE YEAR(p.date_published) = 2025
),

-- Desk Refuse p80: submission -> first desk refuse decision (9)
desk_refuse AS (
    SELECT
        DATEDIFF(ed.date_decided, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(ed.date_decided, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed ON ed.submission_id = b.submission_id AND ed.decision = 9
    WHERE ed.edit_decision_id = (
        SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
        WHERE ed2.submission_id = b.submission_id AND ed2.decision = 9
    )
),

-- Decline p80: submission -> decline decision (4)
-- Single decline only for p80 reliability; absolute count uses counts CTE
declines AS (
    SELECT
        DATEDIFF(ed.date_decided, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(ed.date_decided, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed ON ed.submission_id = b.submission_id AND ed.decision = 4
    WHERE (
        SELECT COUNT(*) FROM edit_decisions ed2
        WHERE ed2.submission_id = b.submission_id AND ed2.decision = 4
    ) = 1
),

-- Accept p80: submission -> first accept decision (1)
acceptances AS (
    SELECT
        DATEDIFF(ed.date_decided, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(ed.date_decided, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed ON ed.submission_id = b.submission_id AND ed.decision = 1
    WHERE ed.edit_decision_id = (
        SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
        WHERE ed2.submission_id = b.submission_id AND ed2.decision = 1
    )
),

-- Review p80: submission -> first Send to Review decision (8)
review AS (
    SELECT
        DATEDIFF(ed.date_decided, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(ed.date_decided, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed ON ed.submission_id = b.submission_id AND ed.decision = 8
    WHERE ed.edit_decision_id = (
        SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
        WHERE ed2.submission_id = b.submission_id AND ed2.decision = 8
    )
),

-- Reviewing Lapse p80: first Send to Review (8) -> last review-phase decision (1,4,5,6)
reviewing_lapse AS (
    SELECT
        DATEDIFF(last_decision.date_decided, first_send.date_decided) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(last_decision.date_decided, first_send.date_decided)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions first_send
        ON first_send.submission_id = b.submission_id AND first_send.decision = 8
        AND first_send.edit_decision_id = (
            SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
            WHERE ed2.submission_id = b.submission_id AND ed2.decision = 8
        )
    INNER JOIN edit_decisions last_decision
        ON last_decision.submission_id = b.submission_id
        AND last_decision.decision IN (1, 4, 5, 6)
        AND last_decision.edit_decision_id = (
            SELECT MAX(ed2.edit_decision_id) FROM edit_decisions ed2
            WHERE ed2.submission_id = b.submission_id AND ed2.decision IN (1, 4, 5, 6)
        )
),

-- Copyediting p80: submission -> first Send to Copyediting decision (7)
copyediting AS (
    SELECT
        DATEDIFF(ed.date_decided, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(ed.date_decided, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed ON ed.submission_id = b.submission_id AND ed.decision = 7
    WHERE ed.edit_decision_id = (
        SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
        WHERE ed2.submission_id = b.submission_id AND ed2.decision = 7
    )
),

-- Copyediting Lapse p80: Send to Copyediting (7) -> Send to Production (10) or date_published
copyediting_lapse AS (
    SELECT
        DATEDIFF(
            COALESCE(
                (SELECT MIN(ed_prod.date_decided) FROM edit_decisions ed_prod
                 WHERE ed_prod.submission_id = b.submission_id AND ed_prod.decision = 10),
                (SELECT p.date_published FROM publications p
                 WHERE p.submission_id = b.submission_id AND p.status = 3 LIMIT 1)
            ),
            ed_copy.date_decided
        ) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(
            COALESCE(
                (SELECT MIN(ed_prod.date_decided) FROM edit_decisions ed_prod
                 WHERE ed_prod.submission_id = b.submission_id AND ed_prod.decision = 10),
                (SELECT p.date_published FROM publications p
                 WHERE p.submission_id = b.submission_id AND p.status = 3 LIMIT 1)
            ),
            ed_copy.date_decided
        )) AS rn,
        COUNT(*) OVER () AS total
    FROM base b
    INNER JOIN edit_decisions ed_copy
        ON ed_copy.submission_id = b.submission_id AND ed_copy.decision = 7
        AND ed_copy.edit_decision_id = (
            SELECT MIN(ed2.edit_decision_id) FROM edit_decisions ed2
            WHERE ed2.submission_id = b.submission_id AND ed2.decision = 7
        )
),

-- Publish p80: submission -> date_published
-- Population: articles published in 2025, anchored to the 2025 publication version
publications_cte AS (
    SELECT
        DATEDIFF(p.date_published, b.date_submitted) AS days,
        ROW_NUMBER() OVER (ORDER BY DATEDIFF(p.date_published, b.date_submitted)) AS rn,
        COUNT(*) OVER () AS total
    FROM base_published b
    INNER JOIN publications p
        ON p.submission_id = b.submission_id
        AND p.status = 3
        AND YEAR(p.date_published) = 2025
        AND p.publication_id = (
            SELECT MIN(p2.publication_id) FROM publications p2
            WHERE p2.submission_id = b.submission_id
              AND p2.status = 3
              AND YEAR(p2.date_published) = 2025
        )
),

-- Absolute counts: filtered by date_decided (per PKP countByDecisions logic)
-- Reflects decisions TAKEN in 2025, regardless of when the submission was received
counts AS (
    SELECT
        COUNT(DISTINCT CASE WHEN ed.decision = 1 THEN s.submission_id END) AS n_accepted,
        COUNT(DISTINCT CASE WHEN ed.decision = 4 THEN s.submission_id END) AS n_declined,
        COUNT(DISTINCT CASE WHEN ed.decision = 9 THEN s.submission_id END) AS n_desk_refuse,
        COUNT(DISTINCT CASE WHEN ed.decision = 8 THEN s.submission_id END) AS n_reviewed,
        COUNT(DISTINCT CASE WHEN ed.decision = 7 THEN s.submission_id END) AS n_copyediting
    FROM submissions s
    INNER JOIN edit_decisions ed ON ed.submission_id = s.submission_id
        AND ed.decision IN (1, 4, 7, 8, 9)
        AND YEAR(ed.date_decided) = 2025
),

-- Rates: per PKP countByDecisionsForSubmittedDate logic (filter by date_submitted)
-- Denominator = accepted + desk_refuse + decline for submissions received in 2025
rates AS (
    SELECT
        COUNT(DISTINCT CASE WHEN ed.decision = 1 THEN b.submission_id END) AS n_accepted_sub,
        COUNT(DISTINCT CASE WHEN ed.decision = 9 THEN b.submission_id END) AS n_desk_refuse_sub,
        COUNT(DISTINCT CASE WHEN ed.decision = 4 THEN b.submission_id END) AS n_declined_sub
    FROM base b
    LEFT JOIN edit_decisions ed ON ed.submission_id = b.submission_id
        AND ed.decision IN (1, 4, 9)
)

SELECT
    -- Submissions received (date_submitted)
    (SELECT COUNT(*) FROM base)                                              AS `Submissions Received (n)`,

    -- Desk Refuse
    (SELECT days FROM desk_refuse      WHERE rn = CEIL(0.8 * total))        AS `Days to Desk Refuse (p80)`,
    (SELECT n_desk_refuse FROM counts)                                       AS `Submissions Declined - Desk Reject (n)`,

    -- Decline
    (SELECT days FROM declines         WHERE rn = CEIL(0.8 * total))        AS `Days to Reject (p80)`,
    (SELECT n_declined FROM counts)                                          AS `Submissions Declined - After Review (n)`,

    -- Accept
    (SELECT days FROM acceptances      WHERE rn = CEIL(0.8 * total))        AS `Days to Accept (p80)`,
    (SELECT n_accepted FROM counts)                                          AS `Submissions Accepted (n)`,

    -- Review
    (SELECT days FROM review           WHERE rn = CEIL(0.8 * total))        AS `Days to Review (p80)`,
    (SELECT n_reviewed FROM counts)                                          AS `Submissions Reviewed (n)`,

    -- Reviewing Lapse (duration metric, no independent n)
    (SELECT days FROM reviewing_lapse  WHERE rn = CEIL(0.8 * total))        AS `Reviewing Lapse (days p80)`,

    -- Copyediting
    (SELECT days FROM copyediting      WHERE rn = CEIL(0.8 * total))        AS `Days to Copyedit (p80)`,
    (SELECT n_copyediting FROM counts)                                       AS `Copyediting (n)`,

    -- Copyediting Lapse (duration metric, no independent n)
    (SELECT days FROM copyediting_lapse WHERE rn = CEIL(0.8 * total))       AS `Copyediting Lapse (days p80)`,

    -- Publish
    (SELECT days FROM publications_cte WHERE rn = CEIL(0.8 * total))        AS `Days to Publish (p80)`,
    (SELECT COUNT(*) FROM base_published)                                    AS `Submissions Published (n)`,

    -- Rates (countByDecisionsForSubmittedDate: filter by date_submitted)
    CONCAT(ROUND(100.0 * n_accepted_sub / NULLIF(n_accepted_sub + n_desk_refuse_sub + n_declined_sub, 0), 1), '%') AS `Acceptance Rate`,
    CONCAT(ROUND(100.0 * (n_desk_refuse_sub + n_declined_sub) / NULLIF(n_accepted_sub + n_desk_refuse_sub + n_declined_sub, 0), 1), '%') AS `Rejection Rate`

FROM rates;
