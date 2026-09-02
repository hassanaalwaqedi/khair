// Package eventmessage provides event-scoped direct messaging. It never
// accepts an arbitrary recipient: every operation begins with an event
// registration and organizer ownership check in PostgreSQL.
package eventmessage

import (
	"database/sql"
	"errors"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/khair/backend/internal/notification"
	"github.com/khair/backend/internal/push"
	"github.com/khair/backend/pkg/response"
	"net/http"
	"strings"
	"time"
)

type Handler struct {
	db            *sql.DB
	notifications *notification.Service
	push          *push.Service
}

func NewHandler(db *sql.DB, services ...interface{}) *Handler {
	h := &Handler{db: db}
	for _, service := range services {
		switch value := service.(type) {
		case *notification.Service:
			h.notifications = value
		case *push.Service:
			h.push = value
		}
	}
	return h
}
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, auth, admin gin.HandlerFunc) {
	g := r.Group("/event-messages", auth)
	g.POST("/conversations", h.open)
	g.GET("/conversations", h.list)
	g.GET("/conversations/:id/messages", h.messages)
	g.POST("/conversations/:id/messages", h.send)
	g.POST("/conversations/:id/read", h.read)
	g.POST("/conversations/:id/mute", h.mute)
	g.POST("/conversations/:id/block-organizer", h.block)
	g.DELETE("/conversations/:id/block-organizer", h.unblock)
	g.POST("/conversations/:id/report-organizer", h.reportOrganizer)
	g.POST("/messages/:id/report", h.reportMessage)
	a := r.Group("/admin/event-messages", auth, admin)
	a.GET("/reports", h.reports)
	a.POST("/permissions/suspend", h.suspend)
}
func uid(c *gin.Context) (uuid.UUID, bool) {
	v, ok := c.Get("user_id")
	id, ok2 := v.(uuid.UUID)
	if !ok || !ok2 {
		response.Unauthorized(c, "Unauthorized")
		return uuid.Nil, false
	}
	return id, true
}
func parse(c *gin.Context) (uuid.UUID, bool) {
	id, e := uuid.Parse(c.Param("id"))
	if e != nil {
		response.BadRequest(c, "Invalid ID")
		return uuid.Nil, false
	}
	return id, true
}
func (h *Handler) open(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	var q struct {
		EventID    string `json:"event_id"`
		AttendeeID string `json:"attendee_id,omitempty"`
	}
	if c.ShouldBindJSON(&q) != nil {
		response.BadRequest(c, "Invalid conversation request")
		return
	}
	eid, e := uuid.Parse(q.EventID)
	if e != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	attendee := me
	var org uuid.UUID
	e = h.db.QueryRow(`SELECT e.organizer_id FROM events e JOIN organizers o ON o.id=e.organizer_id WHERE e.id=$1 AND EXISTS(SELECT 1 FROM event_registrations er WHERE er.event_id=e.id AND er.user_id=$2 AND er.status IN ('pending','confirmed','approved'))`, eid, me).Scan(&org)
	if e != nil { // organizer-started: target must be a real registrant
		if q.AttendeeID == "" {
			response.Forbidden(c, "You can only message attendees connected to this event")
			return
		}
		attendee, e = uuid.Parse(q.AttendeeID)
		if e != nil {
			response.BadRequest(c, "Invalid attendee ID")
			return
		}
		e = h.db.QueryRow(`SELECT e.organizer_id FROM events e JOIN organizers o ON o.id=e.organizer_id WHERE e.id=$1 AND o.user_id=$2 AND EXISTS(SELECT 1 FROM event_registrations er WHERE er.event_id=e.id AND er.user_id=$3 AND er.status IN ('pending','confirmed','approved'))`, eid, me, attendee).Scan(&org)
		if e != nil {
			response.Forbidden(c, "Event relationship required")
			return
		}
	}
	var id uuid.UUID
	e = h.db.QueryRow(`INSERT INTO conversations(event_id,organizer_id,attendee_id) VALUES($1,$2,$3) ON CONFLICT(event_id,attendee_id) DO UPDATE SET updated_at=NOW() RETURNING id`, eid, org, attendee).Scan(&id)
	if e != nil {
		response.InternalServerError(c, "Unable to open conversation")
		return
	}
	_, _ = h.db.Exec(`INSERT INTO conversation_participants(conversation_id,user_id) VALUES($1,$2),($1,$3) ON CONFLICT DO NOTHING`, id, me, attendee)
	response.Success(c, gin.H{"id": id, "event_id": eid, "attendee_id": attendee})
}
func (h *Handler) allowed(id, user uuid.UUID) (bool, error) {
	var x bool
	e := h.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM conversations c JOIN organizers o ON o.id=c.organizer_id WHERE c.id=$1 AND (c.attendee_id=$2 OR o.user_id=$2) AND NOT EXISTS(SELECT 1 FROM blocked_users b WHERE (b.blocker_id=c.attendee_id AND b.blocked_id=o.user_id) OR (b.blocker_id=o.user_id AND b.blocked_id=c.attendee_id)) AND NOT EXISTS(SELECT 1 FROM organizer_message_permissions p WHERE p.organizer_id=c.organizer_id AND p.attendee_id=c.attendee_id AND p.event_id=c.event_id AND p.suspended_at IS NOT NULL))`, id, user).Scan(&x)
	return x, e
}
func (h *Handler) list(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	rows, e := h.db.Query(`SELECT c.id,c.event_id,e.title,c.attendee_id,o.user_id,c.last_message_at,COALESCE((SELECT count(*) FROM messages m WHERE m.conversation_id=c.id AND m.created_at>COALESCE(p.last_read_at,'epoch')),0),CASE WHEN c.attendee_id=$1 THEN COALESCE(o.name,'Organizer') ELSE COALESCE(u.display_name,'Attendee') END,CASE WHEN c.attendee_id=$1 THEN COALESCE(o.logo_url,'') ELSE '' END FROM conversations c JOIN events e ON e.id=c.event_id JOIN organizers o ON o.id=c.organizer_id JOIN users u ON u.id=c.attendee_id LEFT JOIN conversation_participants p ON p.conversation_id=c.id AND p.user_id=$1 WHERE (c.attendee_id=$1 OR o.user_id=$1) AND ((c.attendee_id=$1 AND c.attendee_deleted_at IS NULL) OR (o.user_id=$1 AND c.organizer_deleted_at IS NULL)) ORDER BY c.last_message_at DESC NULLS LAST`, me)
	if e != nil {
		response.InternalServerError(c, "Unable to load conversations")
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, eid, att, org uuid.UUID
		var title, otherName, otherAvatar string
		var last *time.Time
		var unread int
		if rows.Scan(&id, &eid, &title, &att, &org, &last, &unread, &otherName, &otherAvatar) == nil {
			out = append(out, gin.H{"id": id, "event_id": eid, "event_title": title, "attendee_id": att, "organizer_user_id": org, "participant_name": otherName, "participant_avatar": otherAvatar, "last_message_at": last, "unread_count": unread})
		}
	}
	response.Success(c, out)
}
func (h *Handler) messages(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	a, _ := h.allowed(id, me)
	if !a {
		response.Forbidden(c, "Conversation unavailable")
		return
	}
	rows, e := h.db.Query(`SELECT id,sender_id,body,risk_flags,moderation_status,created_at FROM messages WHERE conversation_id=$1 AND deleted_at IS NULL ORDER BY created_at`, id)
	if e != nil {
		response.InternalServerError(c, "Unable to load messages")
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var mid, s uuid.UUID
		var b, f, st string
		var t time.Time
		if rows.Scan(&mid, &s, &b, &f, &st, &t) == nil {
			out = append(out, gin.H{"id": mid, "sender_id": s, "body": b, "risk_flags": f, "moderation_status": st, "created_at": t})
		}
	}
	_, _ = h.db.Exec(`UPDATE conversation_participants SET last_read_at=NOW() WHERE conversation_id=$1 AND user_id=$2`, id, me)
	response.Success(c, out)
}
func risky(s string) bool {
	s = strings.ToLower(s)
	for _, x := range []string{"crypto", "bitcoin", "password", "verification code", "send money", "wire transfer", "paypal.me", "http://"} {
		if strings.Contains(s, x) {
			return true
		}
	}
	return false
}
func (h *Handler) send(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	var q struct {
		Body        string `json:"body"`
		ConfirmRisk bool   `json:"confirm_risk"`
	}
	if c.ShouldBindJSON(&q) != nil || len([]rune(strings.TrimSpace(q.Body))) == 0 {
		response.BadRequest(c, "Message is required")
		return
	}
	if len([]rune(q.Body)) > 4000 {
		response.BadRequest(c, "Message is too long")
		return
	}
	a, _ := h.allowed(id, me)
	if !a {
		response.Forbidden(c, "Messaging is not available")
		return
	}
	var attendee, orgUser uuid.UUID
	var pending bool
	e := h.db.QueryRow(`SELECT c.attendee_id,o.user_id,c.organizer_opening_pending FROM conversations c JOIN organizers o ON o.id=c.organizer_id WHERE c.id=$1`, id).Scan(&attendee, &orgUser, &pending)
	if e != nil {
		response.NotFound(c, "Conversation not found")
		return
	}
	if me == orgUser && pending {
		response.Forbidden(c, "Wait for the attendee to reply before sending another message")
		return
	}
	var n int
	_ = h.db.QueryRow(`SELECT count(*) FROM messages WHERE sender_id=$1 AND created_at>NOW()-INTERVAL '1 minute'`, me).Scan(&n)
	if n >= 20 {
		response.Error(c, 429, "Message rate limit reached")
		return
	}
	if risky(q.Body) && !q.ConfirmRisk {
		response.Success(c, gin.H{"requires_risk_confirmation": true, "warning": "This message may contain sensitive, payment, or suspicious-link content."})
		return
	}
	flags := "[]"
	if risky(q.Body) {
		flags = `["risk_warning"]`
	}
	var mid uuid.UUID
	e = h.db.QueryRow(`INSERT INTO messages(conversation_id,sender_id,body,risk_flags,moderation_status) VALUES($1,$2,$3,$4,$5) RETURNING id`, id, me, strings.TrimSpace(q.Body), flags, func() string {
		if risky(q.Body) {
			return "flagged"
		}
		return "allowed"
	}()).Scan(&mid)
	if e != nil {
		response.InternalServerError(c, "Unable to send message")
		return
	}
	if me == orgUser {
		_, _ = h.db.Exec(`UPDATE conversations SET organizer_opening_pending=true,last_message_at=NOW() WHERE id=$1`, id)
	} else {
		_, _ = h.db.Exec(`UPDATE conversations SET organizer_opening_pending=false,last_message_at=NOW() WHERE id=$1`, id)
	}
	_, _ = h.db.Exec(`INSERT INTO moderation_events(actor_id,event_id,conversation_id,message_id,action,metadata) SELECT $2,event_id,$1,$3,'message_sent',jsonb_build_object('risk', $4) FROM conversations WHERE id=$1`, id, me, mid, risky(q.Body))
	h.notifyRecipient(id, me, mid)
	response.Created(c, gin.H{"id": mid, "risk_flags": flags})
}

// notifyRecipient creates one localized in-app notification and mirrors it to
// the recipient's active web/mobile push devices. Message bodies are never
// copied into the notification payload; the conversation remains protected by
// the normal authenticated event relationship checks.
func (h *Handler) notifyRecipient(conversationID, senderID, messageID uuid.UUID) {
	if h.notifications == nil {
		return
	}
	var attendee, organizerUser, eventID uuid.UUID
	var eventTitle string
	if err := h.db.QueryRow(`
		SELECT c.attendee_id, o.user_id, c.event_id, e.title
		FROM conversations c
		JOIN organizers o ON o.id = c.organizer_id
		JOIN events e ON e.id = c.event_id
		WHERE c.id = $1`, conversationID).Scan(&attendee, &organizerUser, &eventID, &eventTitle); err != nil {
		return
	}
	recipient := attendee
	if senderID == attendee {
		recipient = organizerUser
	}
	data := map[string]string{
		"event_id":        eventID.String(),
		"event_title":     eventTitle,
		"conversation_id": conversationID.String(),
		"message_id":      messageID.String(),
	}
	presentation, notificationID, created, err := h.notifications.CreateLocalizedOnce(recipient, "message_received", data, "message:"+messageID.String())
	if err != nil || !created {
		return
	}
	data["notification_id"] = notificationID.String()
	data["type"] = "message_received"
	if h.push != nil {
		h.push.SendToUser(recipient, presentation.Title, presentation.Message, data)
	}
}
func (h *Handler) read(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	_, e := h.db.Exec(`UPDATE conversation_participants SET last_read_at=NOW() WHERE conversation_id=$1 AND user_id=$2`, id, me)
	if e != nil {
		response.InternalServerError(c, "Unable to mark read")
		return
	}
	c.Status(204)
}
func (h *Handler) mute(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	_, e := h.db.Exec(`UPDATE conversations SET muted_by_attendee=true WHERE id=$1 AND attendee_id=$2`, id, me)
	if e != nil {
		response.InternalServerError(c, "Unable to mute")
		return
	}
	c.Status(204)
}
func (h *Handler) block(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	_, e := h.db.Exec(`INSERT INTO blocked_users(blocker_id,blocked_id,organizer_id) SELECT c.attendee_id,o.user_id,c.organizer_id FROM conversations c JOIN organizers o ON o.id=c.organizer_id WHERE c.id=$1 AND c.attendee_id=$2 ON CONFLICT DO NOTHING`, id, me)
	if e != nil {
		response.InternalServerError(c, "Unable to block organizer")
		return
	}
	_, _ = h.db.Exec(`UPDATE conversations SET attendee_deleted_at=NOW() WHERE id=$1`, id)
	c.Status(204)
}
func (h *Handler) unblock(c *gin.Context) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	_, _ = h.db.Exec(`DELETE FROM blocked_users b USING conversations c,organizers o WHERE c.id=$1 AND c.attendee_id=$2 AND o.id=c.organizer_id AND b.blocker_id=$2 AND b.blocked_id=o.user_id`, id, me)
	c.Status(204)
}
func (h *Handler) reportOrganizer(c *gin.Context) { h.report(c, false) }
func (h *Handler) reportMessage(c *gin.Context)   { h.report(c, true) }
func (h *Handler) report(c *gin.Context, msg bool) {
	me, ok := uid(c)
	if !ok {
		return
	}
	id, ok := parse(c)
	if !ok {
		return
	}
	var q struct {
		Reason      string `json:"reason"`
		Explanation string `json:"explanation"`
	}
	if c.ShouldBindJSON(&q) != nil {
		response.BadRequest(c, "Invalid report")
		return
	}
	var cid uuid.UUID
	var mid *uuid.UUID
	if msg {
		mid = &id
		_ = h.db.QueryRow(`SELECT conversation_id FROM messages WHERE id=$1`, id).Scan(&cid)
	} else {
		cid = id
	}
	_, e := h.db.Exec(`INSERT INTO message_reports(message_id,conversation_id,reporter_id,reason,explanation) VALUES($1,$2,$3,$4,$5)`, mid, cid, me, q.Reason, q.Explanation)
	if e != nil {
		response.BadRequest(c, "Unable to submit report")
		return
	}
	_, _ = h.db.Exec(`INSERT INTO moderation_events(actor_id,conversation_id,message_id,action) VALUES($1,$2,$3,'report_created')`, me, cid, mid)
	c.Status(http.StatusCreated)
}
func (h *Handler) reports(c *gin.Context) {
	rows, e := h.db.Query(`SELECT id,conversation_id,message_id,reason,explanation,created_at FROM message_reports ORDER BY created_at DESC LIMIT 100`)
	if e != nil {
		response.InternalServerError(c, "Unable to load reports")
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, cid uuid.UUID
		var mid *uuid.UUID
		var r string
		var x *string
		var t time.Time
		if rows.Scan(&id, &cid, &mid, &r, &x, &t) == nil {
			out = append(out, gin.H{"id": id, "conversation_id": cid, "message_id": mid, "reason": r, "explanation": x, "created_at": t})
		}
	}
	response.Success(c, out)
}
func (h *Handler) suspend(c *gin.Context) {
	var q struct {
		OrganizerID string `json:"organizer_id"`
		AttendeeID  string `json:"attendee_id"`
		EventID     string `json:"event_id"`
		Reason      string `json:"reason"`
	}
	if c.ShouldBindJSON(&q) != nil {
		response.BadRequest(c, "Invalid suspension")
		return
	}
	o, e := uuid.Parse(q.OrganizerID)
	if e != nil {
		response.BadRequest(c, "Invalid organizer")
		return
	}
	a, e := uuid.Parse(q.AttendeeID)
	if e != nil {
		response.BadRequest(c, "Invalid attendee")
		return
	}
	ev, e := uuid.Parse(q.EventID)
	if e != nil {
		response.BadRequest(c, "Invalid event")
		return
	}
	me, _ := uid(c)
	_, e = h.db.Exec(`INSERT INTO organizer_message_permissions(organizer_id,attendee_id,event_id,suspended_at,suspended_by,reason) VALUES($1,$2,$3,NOW(),$4,$5) ON CONFLICT(organizer_id,attendee_id,event_id) DO UPDATE SET suspended_at=NOW(),suspended_by=$4,reason=$5`, o, a, ev, me, q.Reason)
	if e != nil {
		response.InternalServerError(c, "Unable to suspend messaging")
		return
	}
	c.Status(204)
}

var _ = errors.New
