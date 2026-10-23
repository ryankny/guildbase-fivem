/* ==================================================================
   Staff review panel (/apps)

   A port of the Guildbase dashboard's Applications screens: the same
   table and columns, the same applicant card and figures, the same
   Responses / Events / Risk Analysis tabs, and the same actions in the
   same colours. Someone who reviews on the website should recognise this
   instantly, because it is the same screen.

   Everything on it is drawn from what the server sends. The client holds
   no API key and never decides what a staff member may do: the
   permissions object only decides which buttons are offered, and the
   server checks every action again against the staff member's guild role.

   Answers are applicant-written, so every value that reaches the DOM goes
   through esc(). Nothing here puts a raw API string into innerHTML.
   ================================================================== */

(function () {
    var RESOURCE = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'guildbase-fivem';

    var container = document.getElementById('container');
    var root = document.getElementById('staff');
    var backBtn = document.getElementById('staff-back');
    var titleEl = document.getElementById('staff-title');
    var titlePillEl = document.getElementById('staff-title-pill');
    var subtitleEl = document.getElementById('staff-subtitle');
    var headActions = document.getElementById('staff-head-actions');
    var loadingEl = document.getElementById('staff-loading');
    var toastEl = document.getElementById('staff-toast');

    var views = {
        picker: document.getElementById('view-picker'),
        list: document.getElementById('view-list'),
        detail: document.getElementById('view-detail')
    };

    var modal = {
        wrap: document.getElementById('staff-modal'),
        title: document.getElementById('staff-modal-title'),
        note: document.getElementById('staff-modal-note'),
        fields: document.getElementById('staff-modal-fields'),
        error: document.getElementById('staff-modal-error'),
        close: document.getElementById('staff-modal-close'),
        cancel: document.getElementById('staff-modal-cancel'),
        confirm: document.getElementById('staff-modal-confirm'),
        onConfirm: null
    };

    // Heroicons at the sizes the dashboard uses them.
    var ICON = {
        back: svg('M10 19l-7-7m0 0l7-7m-7 7h18'),
        check: svg('M5 13l4 4L19 7'),
        cross: svg('M6 18L18 6M6 6l12 12'),
        move: svg('M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4'),
        pushback: svg('M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6'),
        claim: svg('M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z'),
        advance: svg('M13 5l7 7-7 7M5 5l7 7-7 7'),
        trash: svg('M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16'),
        scan: svg('M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'),
        chevron: svg('M9 5l7 7-7 7'),
        search: svg('M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z'),
        doc: svg('M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'),
        chat: svg('M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.9 9.9 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z'),
        bars: svg('M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z'),
        warn: svg('M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z'),
        copy: svg('M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z'),
        bolt: svg('M13 10V3L4 14h7v7l9-11h-7z'),
        lock: svg('M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z'),
        discord: '<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16">'
            + '<path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z"></path></svg>'
    };

    function svg(path, size) {
        size = size || 16;

        return '<svg width="' + size + '" height="' + size + '" fill="none" stroke="currentColor"'
            + ' viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round"'
            + ' stroke-width="2" d="' + path + '"/></svg>';
    }

    // The dashboard's status map (application-show.blade.php).
    var STATUS = {
        draft: { label: 'Draft', color: '#a3a3a3' },
        submitted: { label: 'Submitted', color: '#60a5fa' },
        in_review: { label: 'In Review', color: '#fbbf24' },
        pushed_back: { label: 'Pushed Back', color: '#fb923c' },
        accepted: { label: 'Accepted', color: '#4ade80' },
        rejected: { label: 'Rejected', color: '#f87171' },
        withdrawn: { label: 'Withdrawn', color: '#a3a3a3' }
    };

    var FINAL_STATUSES = ['accepted', 'rejected', 'withdrawn'];

    var STATUS_FILTERS = [
        { value: '', label: 'All Statuses' },
        { value: 'pending', label: 'Pending' },
        { value: 'submitted', label: 'Submitted' },
        { value: 'in_review', label: 'In Review' },
        { value: 'accepted', label: 'Accepted' },
        { value: 'rejected', label: 'Rejected' }
    ];

    var RISK_FILTERS = [
        { value: '', label: 'All Risk' },
        { value: 'flagged', label: 'Flagged' },
        { value: 'high', label: 'High' },
        { value: 'medium', label: 'Medium' },
        { value: 'low', label: 'Low' }
    ];

    var FLAG_ICONS = {
        copy_paste: ICON.copy,
        paste_bypass: ICON.copy,
        fast_submission: ICON.bolt,
        sensitive_info: ICON.lock,
        ai_generated: ICON.scan
    };

    // Application::getFlagBadgesAttribute(), so a flag reads the same here as
    // it does on the website.
    var FLAG_LABELS = {
        profanity: 'Profanity',
        sensitive_info: 'Sensitive Info',
        copy_paste: 'Copy/Paste',
        fast_submission: 'Fast Submit',
        spam_patterns: 'Spam Pattern',
        ai_generated: 'AI Generated',
        paste_bypass: 'Paste Bypass',
        low_keystrokes: 'Low Keystrokes',
        unrealistic_typing_speed: 'Inhuman Typing',
        time_manipulated: 'Time Manipulated'
    };

    function flagLabel(flag) {
        return FLAG_LABELS[flag] || String(flag || '').replace(/_/g, ' ').replace(/\b\w/g, function (c) {
            return c.toUpperCase();
        });
    }

    var state = {
        open: false,
        guilds: [],
        guildIndex: null,
        guild: null,
        filters: defaultFilters(),
        applications: [],
        meta: {},
        detail: null,
        tab: 'responses',
        view: 'picker',
        toastTimer: null
    };

    function defaultFilters() {
        return { status: 'pending', page: 1, search: '', template_id: null, risk_level: null };
    }

    // ---- helpers -------------------------------------------------

    function esc(value) {
        if (value === null || value === undefined) return '';

        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function post(endpoint, body) {
        return fetch('https://' + RESOURCE + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body || {})
        }).catch(function () {});
    }

    function busy(on) {
        loadingEl.classList.toggle('hidden', !on);
    }

    function toast(message, kind) {
        if (!message) return;

        toastEl.textContent = message;
        toastEl.className = 'staff-toast' + (kind ? ' is-' + kind : '');

        if (state.toastTimer) clearTimeout(state.toastTimer);

        state.toastTimer = setTimeout(function () {
            toastEl.classList.add('hidden');
        }, 4500);
    }

    /** A colour-at-20%-opacity pill, the way the dashboard tints its stages. */
    function pill(label, color, className) {
        return '<span class="' + (className || 'staff-pill') + '" style="background-color:'
            + esc(color) + '20;color:' + esc(color) + '">' + esc(label) + '</span>';
    }

    function riskTag(level) {
        level = level || 'low';

        return '<span class="staff-tag staff-tag-' + esc(level) + '">'
            + esc(level.charAt(0).toUpperCase() + level.slice(1)) + '</span>';
    }

    function isFinal(application) {
        return FINAL_STATUSES.indexOf(application.status) !== -1;
    }

    function statusOf(application) {
        return STATUS[application.status]
            || { label: application.status || 'Unknown', color: '#a3a3a3' };
    }

    /** The dashboard shows the stage while a application is live, the outcome once it is not. */
    function stateCell(application) {
        if (isFinal(application) || !application.current_stage) {
            var status = statusOf(application);

            return pill(status.label, status.color);
        }

        return pill(application.current_stage.name, application.current_stage.color || '#a855f7');
    }

    function relative(iso) {
        if (!iso) return 'unknown';

        var then = new Date(iso).getTime();
        if (isNaN(then)) return 'unknown';

        var seconds = Math.floor((Date.now() - then) / 1000);
        if (seconds < 60) return 'just now';

        var units = [
            [31536000, 'year'], [2592000, 'month'], [604800, 'week'],
            [86400, 'day'], [3600, 'hour'], [60, 'minute']
        ];

        for (var i = 0; i < units.length; i++) {
            var amount = Math.floor(seconds / units[i][0]);

            if (amount >= 1) {
                return amount + ' ' + units[i][1] + (amount > 1 ? 's' : '') + ' ago';
            }
        }

        return 'just now';
    }

    var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    /** "Jul 20, 2026", as the Submitted column prints it. */
    function shortDate(iso) {
        if (!iso) return null;

        var date = new Date(iso);
        if (isNaN(date.getTime())) return null;

        return MONTHS[date.getMonth()] + ' ' + date.getDate() + ', ' + date.getFullYear();
    }

    function duration(seconds) {
        if (!seconds || seconds < 1) return 'N/A';
        if (seconds < 60) return seconds + 's';

        var minutes = Math.floor(seconds / 60);
        if (minutes < 60) return minutes + 'm ' + (seconds % 60) + 's';

        return Math.floor(minutes / 60) + 'h ' + (minutes % 60) + 'm';
    }

    function titleCase(value) {
        return String(value || '').replace(/_/g, ' ').replace(/^./, function (c) {
            return c.toUpperCase();
        });
    }

    function applicantName(application) {
        return (application.user && (application.user.username || application.user.display_name))
            || 'Unknown applicant';
    }

    /** Falls back to the dashboard's own initials avatar service. */
    function avatar(user, className) {
        var name = (user && (user.username || user.display_name)) || 'U';
        var url = (user && user.avatar_url)
            || ('https://ui-avatars.com/api/?name=' + encodeURIComponent(name) + '&background=8b5cf6&color=fff');

        return '<img class="' + (className || 'staff-avatar') + '" src="' + esc(url) + '" alt="">';
    }

    function permissions() {
        return (state.guild && state.guild.permissions) || {};
    }

    function show(view) {
        state.view = view;

        Object.keys(views).forEach(function (key) {
            views[key].classList.toggle('hidden', key !== view);
        });

        var canGoBack = (view === 'detail') || (view === 'list' && state.guilds.length > 1);

        backBtn.classList.toggle('hidden', !canGoBack);
    }

    // ---- guild picker --------------------------------------------

    function renderPicker() {
        state.guild = null;
        state.guildIndex = null;

        titleEl.textContent = 'Applications';
        titlePillEl.innerHTML = '';
        subtitleEl.textContent = 'Choose which guild to review';
        headActions.innerHTML = '';

        var html = '<div class="staff-picker"><div class="staff-guild-grid">';

        state.guilds.forEach(function (entry) {
            var guild = entry.guild || {};
            var staff = entry.staff || {};
            var counts = entry.counts || {};
            var role = staff.is_owner ? 'Owner' : ((staff.role && staff.role.name) || 'Team member');
            var logo = guild.logo_url
                || ('https://ui-avatars.com/api/?name=' + encodeURIComponent(guild.name || 'G')
                    + '&background=8b5cf6&color=fff');

            html += '<button class="staff-guild-card" type="button" data-guild="' + esc(entry.index) + '">'
                + '<img class="staff-guild-logo" src="' + esc(logo) + '" alt="">'
                + '<div><div class="staff-guild-name">' + esc(guild.name || 'Guild') + '</div>'
                + '<div class="staff-guild-role">' + esc(role) + '</div>'
                + '<div class="staff-guild-counts">'
                + '<span class="staff-tag' + (counts.open ? ' staff-tag-medium' : '') + '">'
                + esc(counts.open || 0) + ' to review</span>'
                + (counts.flagged ? '<span class="staff-tag staff-tag-high">' + esc(counts.flagged) + ' flagged</span>' : '')
                + '</div></div></button>';
        });

        views.picker.innerHTML = html + '</div></div>';

        views.picker.querySelectorAll('[data-guild]').forEach(function (node) {
            node.addEventListener('click', function () {
                selectGuild(parseInt(node.getAttribute('data-guild'), 10));
            });
        });

        show('picker');
    }

    function selectGuild(index) {
        var entry = null;

        state.guilds.forEach(function (candidate) {
            if (candidate.index === index) entry = candidate;
        });

        if (!entry) return;

        state.guildIndex = index;
        state.guild = entry;
        state.filters = defaultFilters();

        renderListShell();
        show('list');
        requestList();
    }

    // ---- list ----------------------------------------------------

    function listHeader() {
        var guild = (state.guild && state.guild.guild) || {};
        var staff = (state.guild && state.guild.staff) || {};
        var role = staff.is_owner ? 'Owner' : ((staff.role && staff.role.name) || 'Team member');

        titleEl.textContent = guild.name ? guild.name + ' · Applications' : 'Applications';
        titlePillEl.innerHTML = '';
        subtitleEl.textContent = 'Manage and review all applications — as '
            + (staff.username || 'you') + ' (' + role + ')';
        headActions.innerHTML = '';
    }

    function renderListShell() {
        listHeader();

        var templates = (state.guild && state.guild.templates) || [];

        var html = '<div class="staff-card" style="display:flex;flex-direction:column;min-height:0;flex:1 1 auto">'
            + '<div class="staff-filters">'
            + '<div class="staff-search">' + ICON.search
            + '<input id="staff-search" class="staff-input" type="text" maxlength="100"'
            + ' placeholder="Search by name, Discord username, Discord ID..."></div>'
            + '<div class="staff-filter-grid">'
            + select('staff-status', STATUS_FILTERS, state.filters.status)
            + select('staff-template', [{ value: '', label: 'All Templates' }].concat(
                templates.map(function (template) {
                    return { value: template.id, label: template.name };
                })
            ), '')
            + select('staff-risk', RISK_FILTERS, '')
            + '</div></div>'
            + '<div class="staff-table-wrap" id="staff-table-wrap"></div>'
            + '<div class="staff-table-footer" id="staff-footer"></div>'
            + '</div>';

        views.list.innerHTML = html;

        var search = views.list.querySelector('#staff-search');
        var searchTimer = null;

        search.value = state.filters.search || '';
        search.addEventListener('input', function () {
            if (searchTimer) clearTimeout(searchTimer);

            searchTimer = setTimeout(function () {
                state.filters.search = search.value.trim();
                state.filters.page = 1;
                requestList();
            }, 450);
        });

        views.list.querySelector('#staff-status').addEventListener('change', function (event) {
            state.filters.status = event.target.value;
            state.filters.page = 1;
            requestList();
        });

        views.list.querySelector('#staff-template').addEventListener('change', function (event) {
            var value = parseInt(event.target.value, 10);

            state.filters.template_id = isNaN(value) ? null : value;
            state.filters.page = 1;
            requestList();
        });

        views.list.querySelector('#staff-risk').addEventListener('change', function (event) {
            state.filters.risk_level = event.target.value || null;
            state.filters.page = 1;
            requestList();
        });
    }

    function select(id, options, selected) {
        var html = '<select id="' + id + '" class="staff-select">';

        options.forEach(function (option) {
            html += '<option value="' + esc(option.value) + '"'
                + (String(option.value) === String(selected) ? ' selected' : '') + '>'
                + esc(option.label) + '</option>';
        });

        return html + '</select>';
    }

    function requestList() {
        busy(true);
        post('staffList', { guildIndex: state.guildIndex, filters: state.filters });
    }

    function renderRows() {
        var wrap = views.list.querySelector('#staff-table-wrap');
        var footer = views.list.querySelector('#staff-footer');

        if (!wrap) return;

        if (!state.applications.length) {
            wrap.innerHTML = '<div class="staff-empty">' + svg(
                'M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 '
                + '01.293.707V19a2 2 0 01-2 2z', 48)
                + '<h3>No applications found</h3><p>Try adjusting your filters.</p></div>';
            footer.innerHTML = '';

            return;
        }

        var html = '<table class="staff-table"><thead><tr>'
            + '<th>Applicant</th>'
            + '<th class="staff-col-template">Template</th>'
            + '<th>Stage</th>'
            + '<th>Risk</th>'
            + '<th>Submitted</th>'
            + '<th class="staff-col-reviewer">Reviewer</th>'
            + '<th class="staff-col-chevron"></th>'
            + '</tr></thead><tbody>';

        state.applications.forEach(function (application) {
            var user = application.user || {};
            var template = (application.template && application.template.name) || 'Unknown';
            var submitted = shortDate(application.submitted_at);
            var flags = (application.flags || []).slice(0, 3);
            var extraFlags = (application.flags || []).length - flags.length;

            html += '<tr data-id="' + esc(application.id) + '">'
                + '<td><div class="staff-cell-applicant">' + avatar(user)
                + '<div style="min-width:0">'
                + '<p class="staff-cell-name">' + esc(applicantName(application)) + '</p>'
                + '<p class="staff-cell-sub">'
                + esc(user.discord_username || ('@' + (user.username || 'unknown'))) + '</p></div>'
                + (flags.length
                    ? '<div class="staff-flagset">' + flags.map(function (flag) {
                        return '<span class="staff-flag" title="' + esc(flagLabel(flag)) + '">'
                            + (FLAG_ICONS[flag] || ICON.warn) + '</span>';
                    }).join('') + (extraFlags > 0
                        ? '<span class="staff-cell-dash">+' + extraFlags + '</span>' : '') + '</div>'
                    : '')
                + '</div></td>'
                + '<td class="staff-col-template"><p class="staff-cell-muted">' + esc(template) + '</p></td>'
                + '<td>' + stateCell(application) + '</td>'
                + '<td>' + riskTag(application.risk_level) + '</td>'
                + '<td>' + (submitted
                    ? '<p class="staff-cell-muted">' + esc(submitted) + '</p>'
                        + '<p class="staff-cell-sub">' + esc(relative(application.submitted_at)) + '</p>'
                    : '<span class="staff-cell-dash">Draft</span>') + '</td>'
                + '<td class="staff-col-reviewer">' + (application.is_claimed
                    ? '<div class="staff-claimed">' + avatar(application.claimed_by)
                        + '<span>Claimed</span></div>'
                    : '<span class="staff-cell-dash">&mdash;</span>') + '</td>'
                + '<td class="staff-col-chevron" style="text-align:right">'
                + '<span class="staff-chevron">' + ICON.chevron + '</span></td>'
                + '</tr>';
        });

        wrap.innerHTML = html + '</tbody></table>';

        wrap.querySelectorAll('[data-id]').forEach(function (node) {
            node.addEventListener('click', function () {
                openApplication(node.getAttribute('data-id'));
            });
        });

        renderFooter(footer);
    }

    function renderFooter(footer) {
        var meta = state.meta || {};
        var page = meta.current_page || 1;
        var last = meta.last_page || 1;
        var perPage = meta.per_page || state.applications.length;
        var total = meta.total || state.applications.length;
        var from = total ? ((page - 1) * perPage) + 1 : 0;
        var to = Math.min(total, from + state.applications.length - 1);

        footer.innerHTML = '<p><b>' + esc(from) + '</b>–<b>' + esc(to) + '</b> of <b>'
            + esc(total) + '</b></p>'
            + (last > 1
                ? '<div class="staff-pager">'
                    + '<button class="staff-btn staff-btn-secondary staff-btn-sm" type="button" data-page="prev"'
                    + (page <= 1 ? ' disabled' : '') + '>Previous</button>'
                    + '<button class="staff-btn staff-btn-secondary staff-btn-sm" type="button" data-page="next"'
                    + (page >= last ? ' disabled' : '') + '>Next</button></div>'
                : '');

        footer.querySelectorAll('[data-page]').forEach(function (node) {
            node.addEventListener('click', function () {
                state.filters.page = node.getAttribute('data-page') === 'next' ? page + 1 : page - 1;
                requestList();
            });
        });
    }

    // ---- detail --------------------------------------------------

    function openApplication(id) {
        busy(true);
        post('staffView', { guildIndex: state.guildIndex, applicationId: id });
    }

    function renderDetail() {
        var detail = state.detail;

        if (!detail || !detail.application) return;

        var application = detail.application;
        var user = application.user || {};
        var stats = detail.applicant_stats || {};

        titleEl.textContent = 'Application #' + String(application.id).substring(0, 8);
        titlePillEl.innerHTML = isFinal(application) || !application.current_stage
            ? pill(statusOf(application).label, statusOf(application).color, 'staff-title-pill')
            : pill(application.current_stage.name, application.current_stage.color || '#a855f7', 'staff-title-pill');

        subtitleEl.textContent = '(' + ((application.template && application.template.name) || 'Unknown Template')
            + ') Submitted ' + relative(application.submitted_at || application.created_at);

        renderHeadActions(detail);

        var html = '<div class="staff-detail">'
            + '<div class="staff-card staff-card-pad">'
            + '<div class="staff-applicant"><div class="staff-applicant-left">'
            + avatar(user, 'staff-applicant-avatar')
            + '<div><h2 class="staff-applicant-name">' + esc(applicantName(application)) + '</h2>'
            + '<div class="staff-applicant-meta">'
            + (user.discord_username
                ? '<span>' + ICON.discord + esc(user.discord_username) + '</span>'
                : '')
            + (user.discord_id ? '<span>' + esc(user.discord_id) + '</span>' : '')
            + '</div></div></div></div>'
            + '<div class="staff-stats">'
            + stat(stats.total_applications !== undefined ? stats.total_applications : '—', 'Total Applications')
            + stat(stats.days_since_joined !== undefined ? stats.days_since_joined : '—', 'Days Since Joined')
            + stat(duration(application.time_spent_seconds), 'Time Spent On App')
            + '</div></div>'
            + renderTabs(detail)
            + '<div id="staff-tab-panel"></div>'
            + '</div>';

        views.detail.innerHTML = html;

        views.detail.querySelectorAll('[data-tab]').forEach(function (node) {
            node.addEventListener('click', function () {
                state.tab = node.getAttribute('data-tab');
                renderTabPanel();

                views.detail.querySelectorAll('[data-tab]').forEach(function (other) {
                    other.classList.toggle('is-active', other === node);
                });
            });
        });

        renderTabPanel();
        show('detail');
    }

    function stat(value, label) {
        return '<div class="staff-stat"><p class="staff-stat-value">' + esc(value)
            + '</p><p class="staff-stat-label">' + esc(label) + '</p></div>';
    }

    function renderTabs(detail) {
        var risk = detail.application.risk_level || 'low';
        var events = (detail.history || []).length;

        var tabs = [
            { key: 'responses', label: 'Responses', icon: ICON.chat, extra: '' },
            {
                key: 'events', label: 'Events', icon: ICON.bars,
                extra: '<span class="staff-tab-count">' + esc(events) + '</span>'
            },
            {
                key: 'risk', label: 'Risk Analysis', icon: ICON.warn,
                extra: riskTag(risk)
            }
        ];

        return '<div class="staff-tabs">' + tabs.map(function (tab) {
            return '<button class="staff-tab' + (state.tab === tab.key ? ' is-active' : '') + '"'
                + ' type="button" data-tab="' + tab.key + '">' + tab.icon
                + '<span>' + esc(tab.label) + '</span>' + tab.extra + '</button>';
        }).join('') + '</div>';
    }

    function renderTabPanel() {
        var panel = views.detail.querySelector('#staff-tab-panel');

        if (!panel) return;

        if (state.tab === 'events') {
            panel.innerHTML = renderEvents(state.detail);
        } else if (state.tab === 'risk') {
            panel.innerHTML = renderRisk(state.detail);

            var scan = panel.querySelector('[data-action="aicheck"]');

            if (scan) {
                scan.addEventListener('click', function () {
                    promptAction('aicheck');
                });
            }
        } else {
            panel.innerHTML = renderResponses(state.detail);
        }
    }

    function renderResponses(detail) {
        var sections = detail.application.answers;
        var html = '';

        if (detail.latest_pushback) {
            html += '<div class="staff-card staff-card-pad" style="margin-bottom:24px">'
                + '<div class="staff-note staff-note-amber">'
                + '<b>Pushed back for revisions</b><br>' + esc(detail.latest_pushback.reason)
                + '<br><span style="opacity:.75">by '
                + esc(detail.latest_pushback.pushed_back_by || 'unknown') + ' · '
                + esc(relative(detail.latest_pushback.created_at)) + '</span></div></div>';
        }

        if (!sections || !sections.length) {
            return html + '<div class="staff-card"><div class="staff-empty">' + ICON.doc
                + '<h3>No responses</h3><p>This application has no answers to show.</p></div></div>';
        }

        html += '<div class="staff-card">';

        sections.forEach(function (section) {
            html += '<div class="staff-section-head">' + esc(section.title || 'Section') + '</div>';

            (section.fields || []).forEach(function (field) {
                var value = field.formatted_value;

                if (value === null || value === undefined || value === '') value = '—';

                html += '<div class="staff-qa">'
                    + '<p class="staff-qa-label">' + esc(field.label || '') + '</p>'
                    + '<p class="staff-qa-value">' + esc(value) + '</p></div>';
            });
        });

        return html + '</div>';
    }

    function renderEvents(detail) {
        var history = detail.history || [];

        if (!history.length) {
            return '<div class="staff-card"><div class="staff-empty">' + ICON.bars
                + '<h3>No events yet</h3><p>Stage changes and claims will appear here.</p></div></div>';
        }

        var html = '<div class="staff-card"><div class="staff-timeline">';

        history.forEach(function (entry) {
            html += '<div class="staff-timeline-item">'
                + '<p class="staff-timeline-title">'
                + esc(entry.stage || titleCase(entry.event_type) || 'Update')
                + (entry.event_type && entry.stage ? ' · ' + esc(titleCase(entry.event_type)) : '')
                + '</p>'
                + '<p class="staff-timeline-meta">' + esc(entry.changed_by || 'System') + ' · '
                + esc(relative(entry.entered_at)) + '</p>'
                + (entry.notes ? '<p class="staff-timeline-notes">' + esc(entry.notes) + '</p>' : '')
                + '</div>';
        });

        return html + '</div></div>';
    }

    function renderRisk(detail) {
        var application = detail.application;
        var flags = application.flags || [];
        var ai = detail.ai_detection;
        var canScan = permissions().ai_check;

        var html = '<div class="staff-card staff-card-pad">'
            + '<div class="staff-ai-head"><span class="staff-ai-label">Risk Level</span>'
            + riskTag(application.risk_level) + '</div>';

        html += flags.length
            ? '<div class="staff-flags-row">' + flags.map(function (flag) {
                return '<span class="staff-tag staff-tag-medium">' + esc(flagLabel(flag)) + '</span>';
            }).join('') + '</div>'
            : '<div class="staff-note staff-note-neutral">No flags were raised on this application.</div>';

        html += '</div><div class="staff-card staff-card-pad">'
            + '<div class="staff-ai-head"><span class="staff-ai-label">AI Detection Scan</span>'
            + (canScan
                ? '<button class="staff-btn staff-btn-primary staff-btn-sm" type="button" data-action="aicheck">'
                    + ICON.scan + '<span>' + (ai ? 'Re-run scan' : 'Run scan') + '</span></button>'
                : '')
            + '</div>';

        if (!ai) {
            html += '<div class="staff-note staff-note-neutral">'
                + (canScan
                    ? 'No scan has been run on this application yet.'
                    : 'No scan has been run. AI detection needs Pro and the view permission.')
                + '</div>';

            return html + '</div>';
        }

        var percent = Math.max(0, Math.min(100, Math.round(ai.overall_percent || 0)));
        var fields = ai.high_probability_fields || [];

        html += '<div class="staff-ai-score"><span class="staff-ai-percent">' + esc(percent) + '%</span>'
            + '<span class="staff-tag ' + (ai.ai_detected
                ? (percent >= 85 ? 'staff-tag-high' : 'staff-tag-medium')
                : 'staff-tag-low') + '">'
            + (ai.ai_detected ? 'AI content detected' : 'Looks human-written') + '</span></div>'
            + '<div class="staff-ai-bar"><div class="staff-ai-bar-fill" style="width:' + percent + '%"></div></div>'
            + kv('Fields analysed', ai.total_analyzed || 0)
            + kv('Fields too short', ai.total_skipped || 0)
            + kv('Flagged fields', fields.length)
            + kv('Last scanned', relative(ai.scanned_at));

        if (fields.length) {
            html += '<div style="margin-top:16px"><p class="staff-ai-label" style="margin-bottom:8px">'
                + 'Highest scoring answers</p>';

            fields.forEach(function (field) {
                if (typeof field === 'string') {
                    html += kv(field, '');

                    return;
                }

                html += kv(field.field || field.label || 'Answer',
                    Math.round((field.score || 0) * 100) + '%');
            });

            html += '</div>';
        }

        return html + '</div>';
    }

    function kv(key, value) {
        return '<div class="staff-kv"><span class="staff-kv-key">' + esc(key)
            + '</span><span class="staff-kv-value">' + esc(value) + '</span></div>';
    }

    /**
     * The dashboard's header action row: accept and reject first, a divider,
     * then the rest. Only what this staff member's role allows is drawn.
     */
    function renderHeadActions(detail) {
        var application = detail.application;
        var perms = permissions();
        var final = isFinal(application);
        var primary = [];
        var secondary = [];

        if (!final && perms.review) {
            primary.push(button('approve', 'Accept', 'staff-btn-accept', ICON.check));
            primary.push(button('reject', 'Reject', 'staff-btn-reject', ICON.cross));
        }

        if (!final && perms.manage) {
            if ((detail.stages || []).length) {
                secondary.push(button('move', 'Move', 'staff-btn-secondary', ICON.move));
            }

            secondary.push(button('advance', 'Advance', 'staff-btn-secondary', ICON.advance));
        }

        if (!final && perms.review && detail.can_be_pushed_back) {
            secondary.push(button('pushback', 'Push Back', 'staff-btn-pushback', ICON.pushback));
        }

        if (final && perms.overturn) {
            secondary.push(button('overturn', 'Overturn', 'staff-btn-overturn', ICON.pushback));
        }

        if (!final && perms.claim) {
            secondary.push(application.is_claimed
                ? button('unclaim', 'Unclaim', 'staff-btn-secondary', ICON.claim)
                : button('claim', 'Claim', 'staff-btn-secondary', ICON.claim));
        }

        if (perms.delete) {
            secondary.push(button('delete', 'Delete', 'staff-btn-danger', ICON.trash));
        }

        if (!primary.length && !secondary.length) {
            headActions.innerHTML = '<span class="staff-cell-sub">'
                + 'Your role does not allow any actions on this application.</span>';

            return;
        }

        headActions.innerHTML = primary.join('')
            + (primary.length && secondary.length ? '<span class="staff-head-divider"></span>' : '')
            + secondary.join('');

        headActions.querySelectorAll('[data-action]').forEach(function (node) {
            node.addEventListener('click', function () {
                promptAction(node.getAttribute('data-action'));
            });
        });
    }

    function button(action, label, className, icon) {
        return '<button class="staff-btn ' + className + '" type="button" data-action="' + action + '"'
            + ' title="' + esc(label) + '">' + (icon || '') + '<span>' + esc(label) + '</span></button>';
    }

    // ---- actions -------------------------------------------------

    function stageOptions(stages, excludeFinal, excludeId) {
        return (stages || []).filter(function (stage) {
            if (excludeFinal && stage.is_final) return false;
            if (excludeId && stage.id === excludeId) return false;

            return true;
        }).map(function (stage) {
            return { value: stage.id, label: stage.name };
        });
    }

    function promptAction(action) {
        var detail = state.detail;

        if (!detail) return;

        var application = detail.application;
        var currentStageId = application.current_stage && application.current_stage.id;

        if (action === 'claim' || action === 'unclaim' || action === 'advance' || action === 'aicheck') {
            return runAction(action, {});
        }

        if (action === 'approve') {
            return openModal({
                title: 'Accept this application?',
                note: 'It moves to the workflow\'s accepted stage, which runs whatever that stage does — '
                    + 'granting Discord roles, for example.',
                confirmLabel: 'Accept',
                confirmClass: 'staff-btn-accept',
                onConfirm: function () {
                    runAction('approve', {});

                    return true;
                }
            });
        }

        if (action === 'reject') {
            return openModal({
                title: 'Reject Application',
                note: 'The reason is shown to the applicant and posted to the application channel.',
                fields: field('Reason (optional)', textarea('modal-reason', 'Why is this being rejected?')),
                confirmLabel: 'Reject',
                confirmClass: 'staff-btn-reject',
                onConfirm: function () {
                    var reason = value('modal-reason');

                    runAction('reject', reason ? { reason: reason } : {});

                    return true;
                }
            });
        }

        if (action === 'pushback') {
            return openModal({
                title: 'Push Back for Revisions',
                note: 'The applicant can edit and resubmit. Tell them what needs changing — '
                    + 'at least 10 characters.',
                fields: field('What needs changing', textarea('modal-reason', '')),
                confirmLabel: 'Push Back',
                confirmClass: 'staff-btn-pushback',
                onConfirm: function () {
                    var reason = value('modal-reason');

                    if (reason.length < 10) {
                        modalError('Please write at least 10 characters.');

                        return false;
                    }

                    runAction('pushback', { reason: reason });

                    return true;
                }
            });
        }

        if (action === 'move') {
            var options = stageOptions(detail.stages, false, currentStageId);

            if (!options.length) {
                return toast('There is no other stage to move this to.', 'error');
            }

            return openModal({
                title: 'Move to Stage',
                fields: field('Stage', select('modal-stage', options, ''))
                    + field('Notes (optional)', textarea('modal-notes', '')),
                confirmLabel: 'Move',
                onConfirm: function () {
                    var stageId = parseInt(value('modal-stage'), 10);
                    var notes = value('modal-notes');

                    if (isNaN(stageId)) {
                        modalError('Choose a stage.');

                        return false;
                    }

                    runAction('move', notes
                        ? { stage_id: stageId, notes: notes }
                        : { stage_id: stageId });

                    return true;
                }
            });
        }

        if (action === 'overturn') {
            var activeOptions = stageOptions(detail.stages, true, null);

            if (!activeOptions.length) {
                return toast('This workflow has no active stage to return the application to.', 'error');
            }

            return openModal({
                title: 'Overturn Decision',
                note: 'The final stage\'s actions are reversed where possible, and the application '
                    + 'goes back into review.',
                fields: field('Return to stage', select('modal-stage', activeOptions, ''))
                    + field('Reason', textarea('modal-reason', '')),
                confirmLabel: 'Overturn',
                confirmClass: 'staff-btn-overturn',
                onConfirm: function () {
                    var stageId = parseInt(value('modal-stage'), 10);
                    var reason = value('modal-reason');

                    if (isNaN(stageId)) {
                        modalError('Choose a stage.');

                        return false;
                    }

                    if (!reason) {
                        modalError('A reason is required.');

                        return false;
                    }

                    runAction('overturn', { stage_id: stageId, reason: reason });

                    return true;
                }
            });
        }

        if (action === 'delete') {
            return openModal({
                title: 'Delete Application',
                note: 'This permanently removes the application, its answers and any uploaded files. '
                    + 'It cannot be undone.',
                confirmLabel: 'Delete Permanently',
                confirmClass: 'staff-btn-reject',
                onConfirm: function () {
                    runAction('delete', {});

                    return true;
                }
            });
        }
    }

    function field(label, control) {
        return '<div><label class="staff-field-label">' + esc(label) + '</label>' + control + '</div>';
    }

    function textarea(id, placeholder) {
        return '<textarea id="' + id + '" class="staff-textarea" maxlength="1000" placeholder="'
            + esc(placeholder || '') + '"></textarea>';
    }

    function value(id) {
        var node = document.getElementById(id);

        return node ? (node.value || '').trim() : '';
    }

    function runAction(action, payload) {
        if (!state.detail) return;

        busy(true);
        post('staffAction', {
            guildIndex: state.guildIndex,
            applicationId: state.detail.application.id,
            staffAction: action,
            payload: payload || {}
        });
    }

    // ---- modal ---------------------------------------------------

    function openModal(options) {
        modal.title.textContent = options.title || '';
        modal.note.textContent = options.note || '';
        modal.fields.innerHTML = options.fields || '';
        modal.error.textContent = '';
        modal.error.classList.add('hidden');
        modal.confirm.textContent = options.confirmLabel || 'Confirm';
        modal.confirm.className = 'staff-btn ' + (options.confirmClass || 'staff-btn-primary');
        modal.onConfirm = options.onConfirm || null;
        modal.wrap.classList.remove('hidden');

        var first = modal.fields.querySelector('textarea, select, input');

        if (first) first.focus();
    }

    function closeModal() {
        modal.wrap.classList.add('hidden');
        modal.onConfirm = null;
    }

    function modalError(message) {
        modal.error.textContent = message;
        modal.error.classList.remove('hidden');
    }

    modal.cancel.addEventListener('click', closeModal);
    modal.close.addEventListener('click', closeModal);
    modal.close.innerHTML = ICON.cross;

    modal.confirm.addEventListener('click', function () {
        if (!modal.onConfirm) return closeModal();

        // A handler returns false to keep the dialog open with its error shown.
        if (modal.onConfirm() !== false) closeModal();
    });

    modal.wrap.addEventListener('click', function (event) {
        if (event.target === modal.wrap) closeModal();
    });

    backBtn.innerHTML = ICON.back;

    // ---- open / close --------------------------------------------

    // Shared with the application frame (script.js) so 'tablet' and
    // 'simplified' behave identically in both.
    function applyViewType(viewType, size) {
        if (window.GuildbaseView) {
            window.GuildbaseView.apply(viewType, size);
        }
    }

    function openPanel(message) {
        state.open = true;
        state.guilds = message.guilds || [];
        state.detail = null;
        state.applications = [];
        state.meta = {};
        state.tab = 'responses';

        applyViewType(message.viewType, message.simplifiedSize);

        container.classList.remove('hidden');
        container.classList.add('mode-staff');
        root.classList.remove('hidden');
        busy(false);
        closeModal();

        // One guild and there is nothing to choose: go straight in.
        if (state.guilds.length === 1) {
            selectGuild(state.guilds[0].index);
        } else {
            renderPicker();
        }
    }

    function closePanel(notifyClient) {
        if (!state.open) return;

        state.open = false;
        state.guild = null;
        state.guildIndex = null;
        state.detail = null;

        closeModal();
        busy(false);
        root.classList.add('hidden');
        container.classList.add('hidden');
        container.classList.remove('mode-staff');
        toastEl.classList.add('hidden');

        if (notifyClient) post('staffClose', {});
    }

    function goBack() {
        if (state.view === 'detail') {
            state.detail = null;
            state.tab = 'responses';
            listHeader();
            show('list');

            return;
        }

        if (state.view === 'list' && state.guilds.length > 1) {
            renderPicker();

            return;
        }

        closePanel(true);
    }

    backBtn.addEventListener('click', goBack);

    // ESC steps back out one level at a time, so a mistyped rejection reason
    // does not throw the whole panel away.
    window.addEventListener('keydown', function (event) {
        if (!state.open) return;
        if (event.key !== 'Escape' && event.keyCode !== 27) return;

        event.preventDefault();
        event.stopPropagation();

        if (!modal.wrap.classList.contains('hidden')) {
            closeModal();

            return;
        }

        goBack();
    }, true);

    // ---- messages from the client --------------------------------

    window.addEventListener('message', function (event) {
        var data = event.data || {};

        switch (data.action) {
            case 'staffOpen':
                openPanel(data);
                break;

            case 'staffClose':
                closePanel(false);
                break;

            case 'staffList':
                busy(false);

                if (!data.payload || data.payload.guildIndex !== state.guildIndex) return;

                state.applications = data.payload.applications || [];
                state.meta = data.payload.meta || {};
                renderRows();
                break;

            case 'staffDetail':
                busy(false);

                if (!data.payload || data.payload.guildIndex !== state.guildIndex) return;

                state.detail = data.payload.detail;
                renderDetail();
                break;

            case 'staffActionResult':
                busy(false);
                handleActionResult(data.payload || {});
                break;

            case 'staffError':
                busy(false);
                toast(data.message, 'error');
                break;
        }
    });

    function handleActionResult(payload) {
        if (!payload.success) {
            return toast(payload.message || 'That did not work.', 'error');
        }

        toast(payload.message || 'Done.', 'success');

        if (payload.warning) {
            setTimeout(function () {
                toast(payload.warning, 'error');
            }, 4700);
        }

        // A deleted application has nothing left to show.
        if (payload.action === 'delete') {
            state.detail = null;
            listHeader();
            show('list');
            requestList();

            return;
        }

        // Everything else changed the application, so re-read it and refresh
        // the list behind it rather than guessing the new state.
        if (state.detail && state.detail.application) {
            openApplication(state.detail.application.id);
        }

        post('staffList', { guildIndex: state.guildIndex, filters: state.filters });
    }
})();
