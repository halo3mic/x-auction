import { User } from "lucide-react";

import { Card } from "@/components/ui/card";

export default function SellerInfo() {
  return (
    <Card className="border border-border p-4">
      <div className="flex items-center mb-2">
        <User className="text-primary" size={24} />
        <span className="text-sm font-medium text-muted-foreground ml-2">
          Seller: John Doe
        </span>
      </div>
      <p className="text-sm text-foreground">
        John is a well-known figure in the community, known for his intriguing
        secrets and valuable insights.
      </p>
    </Card>
  );
}
