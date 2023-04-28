const io = @import("io.zig");
const util = @import("util.zig");
const std = @import("std");

const VIDEOCORE_MBOX: usize = io.MMIO_BASE + 0x00_00B_880;
const MBOX_READ: io.MMIORegister = io.MMIORegister.init(VIDEOCORE_MBOX, 0x0);
const MBOX_STATUS: io.MMIORegister = io.MMIORegister.init(VIDEOCORE_MBOX, 0x18);
const MBOX_WRITE: io.MMIORegister = io.MMIORegister.init(VIDEOCORE_MBOX, 0x20);

const MailboxMessageSize: u32 = 36;

const MailboxMessage = [MailboxMessageSize]u32;
const MailboxChannel = enum(u8) {
    Power = 0,
    FrameBuffer = 1,
    VUART = 2,
    VCHIQ = 3,
    LEDs = 4,
    Buttons = 5,
    Touch = 6,
    Count = 7,
    Properties = 8,
};

const MailboxTag = enum(u32) {
    GetSerial = 0x10004,
    SetClock = 0x38002,
    Last = 0x0,
};

const MailboxEmpty: u32 = 0x40000000;
const MailboxFull: u32 = 0x80000000;
const MailboxStatus = enum {
    Ok,
    Full,
    Empty,
};

const MessageTagRequest: u32 = 0;
const MessageTagResponse: u32 = 0x80000000;

pub const Mailbox = struct {
    fn get_new_message() MailboxMessage {
        var message: [MailboxMessageSize]u32 = undefined;
        return message;
    }

    fn read_status() MailboxStatus {
        const raw = MBOX_STATUS.read_raw();
        return switch (raw) {
            MailboxEmpty => MailboxStatus.Empty,
            MailboxFull => MailboxStatus.Full,
            else => MailboxStatus.Ok,
        };
    }

    fn send(message: *MailboxMessage, channel: MailboxChannel) !MailboxMessage {
        var request_payload: [MailboxMessageSize]u32 align(16) = undefined;
        std.mem.copy(u32, &request_payload, &message.*);

        var request = (@truncate(u32, @ptrToInt(&request_payload)) & ~@as(u32, 0xF)) | (@enumToInt(channel));

        while (Mailbox.read_status() == MailboxStatus.Full) {
            util.wait_cycles(1);
        }

        MBOX_WRITE.write_raw(request);

        while (true) {
            while (Mailbox.read_status() == MailboxStatus.Empty) {
                util.wait_cycles(1);
            }

            if (MBOX_READ.read_raw() == request) {
                std.mem.copy(u32, &message.*, &request_payload);
                if (message[1] == MessageTagResponse) {
                    return message.*;
                } else {
                    return error.InvalidMailboxResponse;
                }
            }
        }
    }

    pub fn get_serial_number() !u64 {
        var message: MailboxMessage = get_new_message();

        message[0] = 8 * 4;
        message[1] = MessageTagRequest;
        message[2] = @enumToInt(MailboxTag.GetSerial);
        message[3] = 8;
        message[4] = 8;
        message[5] = 0;
        message[6] = 0;
        message[7] = @enumToInt(MailboxTag.Last);

        const response = try Mailbox.send(&message, MailboxChannel.Properties);

        return @as(u64, response[6]) << 32 | @as(u64, response[5]);
    }

    pub fn set_uart_clock(clock: u32) !void {
        var message: MailboxMessage = get_new_message();

        message[0] = 9 * 4;
        message[1] = MessageTagRequest;
        message[2] = @enumToInt(MailboxTag.SetClock);
        message[3] = 12;
        message[4] = 8;
        message[5] = 2;
        message[6] = clock;
        message[7] = 0;
        message[8] = @enumToInt(MailboxTag.Last);

        _ = try Mailbox.send(&message, MailboxChannel.Properties);
    }
};
