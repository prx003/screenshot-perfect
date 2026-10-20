import { createFileRoute } from "@tanstack/react-router";
import { AicsMeetExperience } from "@/components/aics-meet-experience";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "AICS Meet — Meet the Future. Build What’s Next." },
      {
        name: "description",
        content:
          "Explore web development, robotics, artificial intelligence, and visual effects at AICS Meet, a technology event built for curious students.",
      },
      { property: "og:title", content: "AICS Meet — Meet the Future. Build What’s Next." },
      {
        property: "og:description",
        content: "One student community. Four ways to explore what comes next.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AicsMeetExperience,
});