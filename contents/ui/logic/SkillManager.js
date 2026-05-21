/*
    SPDX-FileCopyrightText: 2026 Denys Madureira <denys@koderoots.org>
    SPDX-License-Identifier: LGPL-2.1-or-later
*/

.pragma library

function expandHomePath(path, homeDir) {
    if (!path) return "";
    var clean = path.trim();
    if (clean.startsWith("~")) {
        return homeDir + clean.substring(1);
    }
    return clean;
}

function shellEscape(str) {
    return String(str).replace(/[^A-Za-z0-9_\-./:]/g, function(c) {
        return "\\" + c;
    });
}

function parseFrontmatter(content) {
    var result = { name: "", description: "" };

    if (!content || !content.startsWith("---")) {
        return result;
    }

    var endIndex = content.indexOf("---", 3);
    if (endIndex === -1) {
        return result;
    }

    var frontmatter = content.substring(3, endIndex).trim();
    var lines = frontmatter.split('\n');

    for (var i = 0; i < lines.length; i++) {
        var trimmed = lines[i].trim();
        var colonIndex = trimmed.indexOf(':');
        if (colonIndex === -1) continue;

        var key = trimmed.substring(0, colonIndex).trim();
        var value = trimmed.substring(colonIndex + 1).trim();

        if (key === "name") {
            result.name = value;
        } else if (key === "description") {
            result.description = value;
        }
    }

    return result;
}

function buildFullCommand(folders, agentPath, homeDir) {
    var lines = [];

    lines.push("echo ---SKILLS_START---");
    for (var i = 0; i < folders.length; i++) {
        var expanded = expandHomePath(folders[i], homeDir);
        lines.push("/usr/bin/find " + shellEscape(expanded) + " -maxdepth 2 -name SKILL.md -type f 2>/dev/null | while IFS= read -r f; do echo \"---SKILL_FILE:$f---\"; /usr/bin/cat \"$f\"; done");
    }
    lines.push("echo ---SKILLS_END---");

    if (agentPath) {
        var expandedAgent = expandHomePath(agentPath, homeDir);
        lines.push("echo ---AGENT_START---");
        lines.push("/usr/bin/cat " + shellEscape(expandedAgent) + " 2>/dev/null");
        lines.push("echo ---AGENT_END---");
    }

    return lines.join("; ");
}

function parseFullOutput(output) {
    var result = { skills: [], agentContent: "" };

    var skillsStart = output.indexOf("---SKILLS_START---");
    var skillsEnd = output.indexOf("---SKILLS_END---");
    var agentStart = output.indexOf("---AGENT_START---");
    var agentEnd = output.lastIndexOf("---AGENT_END---");

    if (skillsStart !== -1 && skillsEnd !== -1) {
        var skillsSection = output.substring(skillsStart + "---SKILLS_START---".length, skillsEnd);
        result.skills = _parseSkillsSection(skillsSection);
    }

    if (agentStart !== -1 && agentEnd !== -1) {
        result.agentContent = output.substring(agentStart + "---AGENT_START---".length, agentEnd).trim();
    }

    return result;
}

function _parseSkillsSection(section) {
    var skills = [];
    var seen = {};

    var lines = section.split("\n");
    var currentFilePath = "";
    var currentContent = "";
    var inFile = false;

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];

        if (line.indexOf("---SKILL_FILE:") === 0 && line.lastIndexOf("---") === line.length - 3) {
            if (inFile && currentFilePath) {
                _addSkill(skills, seen, currentFilePath, currentContent);
            }
            currentFilePath = line.substring("---SKILL_FILE:".length, line.length - 3);
            currentContent = "";
            inFile = true;
            continue;
        }

        if (inFile) {
            if (currentContent.length > 0) currentContent += "\n";
            currentContent += line;
        }
    }

    if (inFile && currentFilePath) {
        _addSkill(skills, seen, currentFilePath, currentContent);
    }

    return skills;
}

function _addSkill(skills, seen, filePath, content) {
    var lastSlash = filePath.lastIndexOf("/");
    var secondLastSlash = filePath.lastIndexOf("/", lastSlash - 1);
    var dirName = "";
    if (lastSlash > 0 && secondLastSlash >= 0) {
        dirName = filePath.substring(secondLastSlash + 1, lastSlash);
    }

    var meta = parseFrontmatter(content);
    var name = meta.name;
    var description = meta.description;

    if (!name && !description) {
        name = dirName;
    }

    if (name && !seen[name]) {
        skills.push({
            name: name,
            description: description,
            directoryName: dirName,
            content: content
        });
        seen[name] = true;
    }
}

function buildSystemMessage(skills, agentContent) {
    var parts = [];

    if (skills && skills.length > 0) {
        var skillLines = ["Available skills (use when the task matches):"];

        for (var i = 0; i < skills.length; i++) {
            var skill = skills[i];
            var name = skill.name || "";
            var description = skill.description || "";

            var line = "- " + name;
            if (description) {
                line += ": " + description;
            }
            skillLines.push(line);
        }

        parts.push(skillLines.join('\n'));
    }

    if (agentContent && agentContent !== "") {
        parts.push("Agent instructions:\n" + agentContent);
    }

    return parts.join("\n\n");
}
