--[[
    not implemented:
    
    channel.chat.clear
    channel.chat.clear_user_messages
    channel.chat.message_delete
    channel.subscription.end
    channel.ban
    channel.unban
    channel.moderator.add
    channel.moderator.remove
    channel.guest_star*
    channel.charity_campaign.*
    extension.bits_transaction.create
    drop.entitlement.grant
    channel.shield_mode.*

]]

local function channel_follow(sessionId, userId)
    return {
        type = "channel.follow",
        version = "2",
        condition = {
            broadcaster_user_id = userId,
            moderator_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_update(sessionId, userId)
    return {
        type = "channel.update",
        version = "2",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function ad_break_begin(sessionId, userId)
    return {
        type = "channel.ad_break.begin",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function chat_notification(sessionId, userId)
    return {
        type = "channel.chat.notification",
        version = "1",
        condition = {
            broadcaster_user_id = userId,
            user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_subscribe(sessionId, userId)
    return {
        type = "channel.subscribe",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_subscribtion_gift(sessionId, userId)
    return {
        type = "channel.subscription.gift",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_subscribtion_message(sessionId, userId)
    return {
        type = "channel.subscription.message",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_cheer(sessionId, userId)
    return {
        type = "channel.cheer",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_raid_from(sessionId, userId)
    return {
        type = "channel.raid",
        version = "1",
        condition = {
            from_broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_raid_to(sessionId, userId)
    return {
        type = "channel.raid",
        version = "1",
        condition = {
            to_broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function reward_add(sessionId, userId)
    return {
        type = "channel.channel_points_custom_reward.add",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function reward_update(sessionId, userId)
    return {
        type = "channel.channel_points_custom_reward.update",
        version = "1",
        condition = {
            broadcaster_user_id = userId
            -- reward_id to filter by reward
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function reward_remove(sessionId, userId)
    return {
        type = "channel.channel_points_custom_reward.remove",
        version = "1",
        condition = {
            broadcaster_user_id = userId
            -- reward_id to filter by reward
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function reward_redemption_add(sessionId, userId)
    return {
        type = "channel.channel_points_custom_reward_redemption.add",
        version = "1",
        condition = {
            broadcaster_user_id = userId
            -- reward_id to filter by reward
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function reward_redemption_update(sessionId, userId)
    return {
        type = "channel.channel_points_custom_reward_redemption.update",
        version = "1",
        condition = {
            broadcaster_user_id = userId
            -- reward_id to filter by reward
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function poll_begin(sessionId, userId)
    return {
        type = "channel.poll.begin",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function poll_progress(sessionId, userId)
    return {
        type = "channel.poll.progress",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function poll_end(sessionId, userId)
    return {
        type = "channel.poll.end",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function prediction_begin(sessionId, userId)
    return {
        type = "channel.prediction.begin",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function prediction_progress(sessionId, userId)
    return {
        type = "channel.prediction.progress",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function prediction_end(sessionId, userId)
    return {
        type = "channel.prediction.end",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_goal_begin(sessionId, userId)
    return {
        type = "channel.goal.begin",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_goal_progress(sessionId, userId)
    return {
        type = "channel.goal.progress",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_goal_end(sessionId, userId)
    return {
        type = "channel.goal.end",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_hype_train_begin(sessionId, userId)
    return {
        type = "channel.hype_train.begin",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_hype_train_progress(sessionId, userId)
    return {
        type = "channel.hype_train.progress",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function channel_hype_train_end(sessionId, userId)
    return {
        type = "channel.hype_train.end",
        version = "1",
        condition = {
            broadcaster_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function shoutout_create(sessionId, userId)
    return {
        type = "channel.shoutout.create",
        version = "1",
        condition = {
            broadcaster_user_id = userId,
            moderator_user_id = userId
        },
        transport = {
            method = "websocket",
            session_id = sessionId
        }
    }
end

local function scopes(sessionId, userId)
    return {
        channel_follow(sessionId, userId),
        channel_update(sessionId, userId),
        ad_break_begin(sessionId, userId),
        chat_notification(sessionId, userId),
        channel_subscribe(sessionId, userId),
        channel_subscribtion_gift(sessionId, userId),
        channel_subscribtion_message(sessionId, userId),
        channel_cheer(sessionId, userId),
        
        -- raid to the channel also triggers chat notification event
        channel_raid_from(sessionId, userId),
        channel_raid_to(sessionId, userId),

        reward_add(sessionId, userId),
        reward_update(sessionId, userId),
        reward_remove(sessionId, userId),
        reward_redemption_add(sessionId, userId),   -- user redeemed something
        reward_redemption_update(sessionId, userId), -- update on the redeem: fulfilled or cancelled
        poll_begin(sessionId, userId),
        poll_progress(sessionId, userId),
        poll_end(sessionId, userId),
        prediction_begin(sessionId, userId),
        prediction_progress(sessionId, userId),
        prediction_end(sessionId, userId),
        channel_goal_begin(sessionId, userId),
        channel_goal_progress(sessionId, userId),
        channel_goal_end(sessionId, userId),
        channel_hype_train_begin(sessionId, userId),
        channel_hype_train_progress(sessionId, userId),
        channel_hype_train_end(sessionId, userId),
        
    }
end

local _M = {}

_M.scopes = scopes

return _M