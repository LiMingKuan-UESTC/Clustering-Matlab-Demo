% Copyright 2026 LI MingKuan
%
% 原项目：Clustering-Matlab-Demo
% 作者：LiMingKuan-UESTC
% 仓库地址：https://github.com/LiMingKuan-UESTC/Clustering-Matlab-Demo

function demo()
% 层次聚类可交互演示demo
%
% 特点：
%   1. 手写 single-linkage / 最小距离准则，不依赖 Statistics Toolbox；
%   2. 支持“上一步、下一步、自动播放、暂停、重置、显示树状图”；
%
% 算法：
%   初始时每个样本自成一类；
%   类间距离采用最小距离准则：
%       D(C_i, C_j) = min ||x - y||, x in C_i, y in C_j
%   每一步合并距离最小的两个类，直到剩下 targetK 类。

clc; close all;

%% 1. 数据区：二维特征样本
X = [
    0.5 1.0
    0.9 1.4
    1.3 0.9
    1.5 1.6
    0.7 0.4

    5.2 0.8
    5.8 1.4
    6.4 0.7
    6.0 2.0
    5.5 2.4

    3.1 5.0
    3.8 5.5
    4.5 5.0
    3.3 6.2
    4.2 6.4
];

targetK = 3;   % 最终希望停止到几类

n = size(X, 1);
names = arrayfun(@(k) sprintf('P%d', k), 1:n, 'UniformOutput', false);

if targetK < 1 || targetK > n
    error('targetK 必须在 1 到样本数之间。');
end

%% 2. 聚类过程预先计算（算总次数）
[states, history] = runSingleLinkage(X);
stopStep = n - targetK;

%% 3. 交互界面
fig = figure( ...
    'Name', '分级聚类 Demo：Single Linkage / 最小距离准则', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [100 80 1100 720], ...
    'CloseRequestFcn', @closeDemo);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.07 0.18 0.62 0.74]);

% text控件，展示聚类过程的信息
infoText = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.72 0.48 0.25 0.42], ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'FontSize', 11);

clusterTitleText = uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.72 0.42 0.25 0.04], ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', 'w', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'String', '当前各类：');

% 添加滚动条展示“当前各类”列表
clusterListBox = uicontrol(fig, ...
    'Style', 'listbox', ...
    'Units', 'normalized', ...
    'Position', [0.72 0.18 0.25 0.23], ...
    'BackgroundColor', 'w', ...
    'FontSize', 11, ...
    'Value', 1);

btnPrev = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '上一步', ...
    'Units', 'normalized', ...
    'Position', [0.07 0.06 0.10 0.06], ...
    'FontSize', 11, ...
    'Callback', @prevStep);

btnNext = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '下一步', ...
    'Units', 'normalized', ...
    'Position', [0.18 0.06 0.10 0.06], ...
    'FontSize', 11, ...
    'Callback', @nextStep);

btnAuto = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '自动播放', ...
    'Units', 'normalized', ...
    'Position', [0.29 0.06 0.10 0.06], ...
    'FontSize', 11, ...
    'Callback', @autoPlay);

btnPause = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '暂停', ...
    'Units', 'normalized', ...
    'Position', [0.40 0.06 0.10 0.06], ...
    'FontSize', 11, ...
    'Callback', @pauseDemo);

btnReset = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '重置', ...
    'Units', 'normalized', ...
    'Position', [0.51 0.06 0.10 0.06], ...
    'FontSize', 11, ...
    'Callback', @resetDemo);

btnTree = uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'String', '显示树状图', ...
    'Units', 'normalized', ...
    'Position', [0.62 0.06 0.12 0.06], ...
    'FontSize', 11, ...
    'Callback', @showTree);

data.X = X;
data.names = names;
data.targetK = targetK;
data.states = states;
data.history = history;
data.stopStep = stopStep;
data.step = 0;
data.ax = ax;
data.infoText = infoText;
data.clusterTitleText = clusterTitleText;
data.clusterListBox = clusterListBox;
data.btnPrev = btnPrev;
data.btnNext = btnNext;
data.btnAuto = btnAuto;
data.btnPause = btnPause;
data.btnReset = btnReset;
data.btnTree = btnTree;
data.timer = [];
guidata(fig, data);

render();

%% 4. 回调函数
    function render()
        if ~ishandle(fig)
            return;
        end

        data = guidata(fig);
        X = data.X;
        names = data.names;
        step = data.step;
        clusters = data.states{step + 1};
        ax = data.ax;

        cla(ax);
        hold(ax, 'on');

        colors = lines(max(7, numel(clusters)));

        % 先画每个类的浅色包络区域
        for c = 1:numel(clusters)
            idx = clusters{c};
            if numel(idx) >= 3
                try
                    k = convhull(X(idx, 1), X(idx, 2));
                    patch(ax, X(idx(k), 1), X(idx(k), 2), colors(c, :), ...
                        'FaceAlpha', 0.08, ...
                        'EdgeColor', colors(c, :), ...
                        'LineWidth', 1.2);
                catch
                    % 如果点共线导致 convhull 失败，则跳过包络区域
                end
            elseif numel(idx) == 2
                plot(ax, X(idx, 1), X(idx, 2), '-', ...
                    'Color', colors(c, :), ...
                    'LineWidth', 1.2);
            end
        end

        % 再画散点和标签
        for c = 1:numel(clusters)
            idx = clusters{c};
            scatter(ax, X(idx, 1), X(idx, 2), 95, ...
                'MarkerFaceColor', colors(c, :), ...
                'MarkerEdgeColor', 'k', ...
                'LineWidth', 0.8);

            for p = idx
                text(ax, X(p, 1) + 0.06, X(p, 2) + 0.06, names{p}, ...
                    'FontSize', 10, ...
                    'FontWeight', 'bold');
            end
        end

        % 高亮下一步将要合并的最近样本对
        if step < data.stopStep
            m = data.history(step + 1);
            a = m.pointA;
            b = m.pointB;
            plot(ax, [X(a, 1), X(b, 1)], [X(a, 2), X(b, 2)], ...
                'k--', 'LineWidth', 2.2);

            titleText = sprintf('第 %d 步：当前有 %d 类；虚线表示下一步将合并的最近样本对', ...
                step, numel(clusters));
        else
            titleText = sprintf('停止：已经合并 %d 次，当前得到 %d 类', ...
                step, numel(clusters));
        end

        grid(ax, 'on');
        axis(ax, 'equal');
        xlim(ax, [min(X(:, 1)) - 0.7, max(X(:, 1)) + 0.8]);
        ylim(ax, [min(X(:, 2)) - 0.7, max(X(:, 2)) + 0.8]);
        xlabel(ax, '特征 1');
        ylabel(ax, '特征 2');
        title(ax, titleText, 'FontSize', 13, 'FontWeight', 'bold');

        % 右侧文字说明
        infoLines = {};
        infoLines{end + 1} = '分级聚类 Demo';
        infoLines{end + 1} = ' ';
        infoLines{end + 1} = sprintf('样本数：%d', size(X, 1));
        infoLines{end + 1} = '准则：欧氏距离 + 最小距离';
        infoLines{end + 1} = sprintf('目标：最终分成 %d 类', data.targetK);
        infoLines{end + 1} = ' ';
        infoLines{end + 1} = sprintf('当前步数：%d', step);
        infoLines{end + 1} = sprintf('当前类数：%d', numel(clusters));
        infoLines{end + 1} = ' ';

        if step == 0
            infoLines{end + 1} = '刚完成：尚未合并';
        else
            prev = data.history(step);
            infoLines{end + 1} = '刚完成：';
            infoLines{end + 1} = sprintf('%s + %s', ...
                clusterString(prev.leftCluster, names), ...
                clusterString(prev.rightCluster, names));
            infoLines{end + 1} = sprintf('合并距离：%.3f', prev.distance);
        end

        infoLines{end + 1} = ' ';

        if step < data.stopStep
            m = data.history(step + 1);
            infoLines{end + 1} = '下一步：';
            infoLines{end + 1} = sprintf('%s + %s', ...
                clusterString(m.leftCluster, names), ...
                clusterString(m.rightCluster, names));
            infoLines{end + 1} = sprintf('最近样本对：%s - %s', names{m.pointA}, names{m.pointB});
            infoLines{end + 1} = sprintf('最小距离：%.3f', m.distance);
        else
            infoLines{end + 1} = '已经达到目标类数。';
            infoLines{end + 1} = '点击“显示树状图”可以看完整聚类树。';
        end

        % 上半部分显示说明文字
        set(data.infoText, 'String', infoLines);

        % 内容多时 listbox 会自动出现滚动条
        clusterLines = clusterListString(clusters, names);
        if isempty(clusterLines)
            set(data.clusterListBox, 'String', {' '}, 'Value', 1);
        else
            set(data.clusterListBox, 'String', clusterLines, 'Value', 1);
        end

        set(data.btnPrev, 'Enable', onoff(step > 0));
        set(data.btnNext, 'Enable', onoff(step < data.stopStep));
        set(data.btnAuto, 'Enable', onoff(step < data.stopStep));

        drawnow;
    end

    function prevStep(~, ~)
        pauseDemo();
        data = guidata(fig);
        if data.step > 0
            data.step = data.step - 1;
            guidata(fig, data);
            render();
        end
    end

    function nextStep(~, ~)
        if ~ishandle(fig)
            return;
        end

        data = guidata(fig);
        if data.step < data.stopStep
            data.step = data.step + 1;
            guidata(fig, data);
            render();
        else
            pauseDemo();
        end
    end

    function autoPlay(~, ~)
        if ~ishandle(fig)
            return;
        end

        data = guidata(fig);

        if isempty(data.timer) || ~isvalid(data.timer)
            data.timer = timer( ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period', 1.0, ...
                'TimerFcn', @(~, ~) nextStep());
            guidata(fig, data);
        end

        if strcmp(data.timer.Running, 'off')
            start(data.timer);
        end
    end

    function pauseDemo(~, ~)
        if ~ishandle(fig)
            return;
        end

        data = guidata(fig);
        if isfield(data, 'timer') && ~isempty(data.timer) && isvalid(data.timer)
            try
                stop(data.timer);
            catch
            end
        end
    end

    function resetDemo(~, ~)
        pauseDemo();
        data = guidata(fig);
        data.step = 0;
        guidata(fig, data);
        render();
    end

    function showTree(~, ~)
        data = guidata(fig);
        plotDendrogramManual(data.history, data.names, data.targetK, data.stopStep);
    end

    function closeDemo(~, ~)
        if ishandle(fig)
            data = guidata(fig);
            if isfield(data, 'timer') && ~isempty(data.timer) && isvalid(data.timer)
                try
                    stop(data.timer);
                    delete(data.timer);
                catch
                end
            end
            delete(fig);
        end
    end
end

%% 算法和绘图辅助函数区域

function [states, history] = runSingleLinkage(X)
% 手写 single-linkage 层次聚类，返回每一步的聚类状态和合并历史。

n = size(X, 1);

clusters = cell(1, n);
nodeIds = cell(1, n);

for i = 1:n
    clusters{i} = i;
    nodeIds{i} = i;
end

states = cell(1, n);
states{1} = clusters;

history = struct( ...
    'leftCluster', {}, ...
    'rightCluster', {}, ...
    'newCluster', {}, ...
    'distance', {}, ...
    'pointA', {}, ...
    'pointB', {}, ...
    'leftNode', {}, ...
    'rightNode', {}, ...
    'newNode', {}, ...
    'newSize', {}, ...
    'nClustersAfter', {});

nextNodeId = n + 1;
step = 0;

while numel(clusters) > 1
    [bestI, bestJ, bestD, pointA, pointB] = findClosestClusters(X, clusters);

    leftCluster = clusters{bestI};
    rightCluster = clusters{bestJ};
    newCluster = sort([leftCluster, rightCluster]);

    entry.leftCluster = leftCluster;
    entry.rightCluster = rightCluster;
    entry.newCluster = newCluster;
    entry.distance = bestD;
    entry.pointA = pointA;
    entry.pointB = pointB;
    entry.leftNode = nodeIds{bestI};
    entry.rightNode = nodeIds{bestJ};
    entry.newNode = nextNodeId;
    entry.newSize = numel(newCluster);
    entry.nClustersAfter = numel(clusters) - 1;

    history(end + 1) = entry; %#ok<AGROW>

    keep = true(1, numel(clusters));
    keep([bestI, bestJ]) = false;

    clusters = clusters(keep);
    nodeIds = nodeIds(keep);

    clusters{end + 1} = newCluster; %#ok<AGROW>
    nodeIds{end + 1} = nextNodeId; %#ok<AGROW>

    [clusters, nodeIds] = sortClustersByFirstSample(clusters, nodeIds);

    step = step + 1;
    states{step + 1} = clusters;

    nextNodeId = nextNodeId + 1;
end
end

function [bestI, bestJ, bestD, bestPointA, bestPointB] = findClosestClusters(X, clusters)
% 找到当前所有类中 single-linkage 距离最小的两个类。

bestD = inf;
bestI = NaN;
bestJ = NaN;
bestPointA = NaN;
bestPointB = NaN;

for i = 1:(numel(clusters) - 1)
    for j = (i + 1):numel(clusters)
        A = clusters{i};
        B = clusters{j};

        for ia = 1:numel(A)
            for ib = 1:numel(B)
                a = A(ia);
                b = B(ib);
                d = sqrt(sum((X(a, :) - X(b, :)).^2));

                % 加入一个极小容差，避免浮点误差导致不稳定
                if d < bestD - 1e-12
                    bestD = d;
                    bestI = i;
                    bestJ = j;
                    bestPointA = a;
                    bestPointB = b;
                end
            end
        end
    end
end
end

function [clusters, nodeIds] = sortClustersByFirstSample(clusters, nodeIds)
% 按每个类中最小样本编号排序，使显示顺序稳定。

firstIndex = cellfun(@min, clusters);
[~, order] = sort(firstIndex);
clusters = clusters(order);
nodeIds = nodeIds(order);
end

function s = clusterString(indices, names)
% 把一个类转换成 {P1,P2,...} 的字符串。

parts = names(indices);
s = ['{' strjoin(parts, ',') '}'];
end

function lines = clusterListString(clusters, names)
% 把当前所有类转换成多行字符串。
% 如果某一类太长，则自动拆成多行，避免右侧列表横向截断。

lines = {};
maxChars = 34;   % 每行大约最多显示多少字符，可按窗口宽度调整

for i = 1:numel(clusters)
    idx = clusters{i};
    parts = names(idx);

    prefix = sprintf('C%d = {', i);
    currentLine = prefix;

    for j = 1:numel(parts)
        if j < numel(parts)
            token = [parts{j} ','];
        else
            token = parts{j};
        end

        if length(currentLine) + length(token) + 1 > maxChars
            lines{end + 1} = currentLine; %#ok<AGROW>
            currentLine = ['     ' token];
        else
            currentLine = [currentLine token]; %#ok<AGROW>
        end
    end

    currentLine = [currentLine '}']; %#ok<AGROW>
    lines{end + 1} = currentLine; %#ok<AGROW>
end

lines = lines(:);
end

function value = onoff(flag)
% 把 true/false 转成 MATLAB uicontrol 的 Enable 属性。

if flag
    value = 'on';
else
    value = 'off';
end
end

function plotDendrogramManual(history, names, targetK, stopStep)
% 手写树状图绘制，不使用 dendrogram 函数，因此不依赖 Statistics Toolbox。

n = numel(names);
maxNode = 2 * n - 1;

nodeX = zeros(1, maxNode);
nodeY = zeros(1, maxNode);

for i = 1:n
    nodeX(i) = i;
    nodeY(i) = 0;
end

figTree = figure( ...
    'Name', '分级聚类树状图', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [160 120 1000 560]);

ax = axes('Parent', figTree);
hold(ax, 'on');

for k = 1:numel(history)
    left = history(k).leftNode;
    right = history(k).rightNode;
    newNode = history(k).newNode;
    h = history(k).distance;

    x1 = nodeX(left);
    x2 = nodeX(right);
    y1 = nodeY(left);
    y2 = nodeY(right);

    plot(ax, [x1 x1], [y1 h], 'k-', 'LineWidth', 1.5);
    plot(ax, [x2 x2], [y2 h], 'k-', 'LineWidth', 1.5);
    plot(ax, [x1 x2], [h h], 'k-', 'LineWidth', 1.5);

    nodeX(newNode) = (x1 + x2) / 2;
    nodeY(newNode) = h;
end

% 切分线：在第 stopStep 次合并距离和下一次合并距离之间切开
if stopStep < numel(history)
    cutHeight = (history(stopStep).distance + history(stopStep + 1).distance) / 2;
else
    cutHeight = history(stopStep).distance;
end

plot(ax, [0.5, n + 0.5], [cutHeight, cutHeight], 'r--', 'LineWidth', 1.8);
text(ax, 0.65, cutHeight, sprintf('  切开后得到 %d 类', targetK), ...
    'Color', 'r', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');

xlim(ax, [0.5, n + 0.5]);
ylim(ax, [0, max([history.distance]) * 1.08]);
set(ax, 'XTick', 1:n, 'XTickLabel', names, 'XTickLabelRotation', 45);
grid(ax, 'on');

xlabel(ax, '样本');
ylabel(ax, '合并距离');
title(ax, '分级聚类树状图：Single Linkage / 最小距离准则', ...
    'FontSize', 13, ...
    'FontWeight', 'bold');
end
