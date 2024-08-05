import { ArrowRight, BookLock, Clock, User } from "lucide-react";
import Link from "next/link";
import Countdown from "react-countdown";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

interface SecretAuctionCardProps {
  id: number;
  description: string;
  userBid: number | null;
  endTime: number;
}

export function SecretAuctionCard({
  id,
  description,
  userBid,
  endTime,
}: SecretAuctionCardProps) {
  return (
    <Card className="flex flex-col hover:shadow-lg transition-all duration-300 bg-secondary/30">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center text-2xl font-bold">
          <BookLock className="text-primary mr-3" size={28} />
          Secret #{id}
        </CardTitle>
      </CardHeader>
      <CardContent className="flex-grow pt-4 flex flex-col">
        <p className="text-muted-foreground mb-6 line-clamp-2 text-sm flex-grow">
          {description}
        </p>
        <div className="flex justify-between items-end mt-auto">
          <div>
            <p className="text-xs font-medium text-muted-foreground mb-1">
              Your Bid
            </p>
            {userBid ? (
              <p className="text-2xl font-bold text-primary flex items-center">
                <User className="mr-2" size={20} />
                {userBid} ETH
              </p>
            ) : (
              <p className="text-sm font-semibold text-muted-foreground">
                No bid placed
              </p>
            )}
          </div>
          <div className="text-right">
            <p className="text-xs font-medium text-muted-foreground mb-1">
              Ends in
            </p>
            <p className="text-sm font-semibold flex items-center justify-end bg-primary/10 rounded-full px-3 py-1">
              <Clock className="mr-1 text-primary" size={14} />
              <Countdown
                date={endTime}
                renderer={({ days, hours, minutes }) => (
                  <span className="text-primary font-bold">
                    {days}d {hours}h {minutes}m
                  </span>
                )}
              />
            </p>
          </div>
        </div>
      </CardContent>
      <CardFooter className="pt-4">
        <Link href={`/bid/${id}`} className="w-full">
          <Button className="w-full group" size="lg">
            <span>{userBid ? "Update Bid" : "Place Bid"}</span>
            <ArrowRight
              className="ml-2 group-hover:translate-x-1 transition-transform"
              size={18}
            />
          </Button>
        </Link>
      </CardFooter>
    </Card>
  );
}
